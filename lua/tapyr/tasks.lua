local tasks = {}

local messages = require("tapyr.messages")
local project = require("tapyr.project")
local app_tasks = {}
local assigned_ports = {}
local preparations = {}
local reserved_ports = {}
local shiny_reload_excludes = ".*,*.py[cod],__pycache__,env,venv"

local tools = {
  run = {
    executable = "shiny",
  },
  test = {
    executable = "pytest",
  },
}

local function get_overseer()
  local ok, overseer = pcall(require, "overseer")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

local function show_task(task)
  local overseer = get_overseer()
  if not overseer then
    return
  end
  overseer.open({
    enter = false,
    focus_task_id = task.id,
  })
end

---@param name "run"|"test"
---@param app TapyrAppDefinition
---@return string?
local function find_executable(name, app)
  local tool = tools[name]
  local directory = app.root
  while directory do
    local environment = vim.fs.joinpath(directory, ".venv")
    local candidate = vim.fs.joinpath(environment, "bin", tool.executable)
    if vim.fn.executable(candidate) == 1 then
      return candidate, environment
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then
      break
    end
    directory = parent
  end

  local executable = vim.fn.exepath(tool.executable)
  if executable and executable ~= "" then
    return executable
  end
end

---@param name "run"|"test"
---@param app TapyrAppDefinition
---@param port? integer
---@return string[]?
function tasks.resolve(name, app, port)
  local executable, environment = find_executable(name, app)
  if not executable then
    return nil
  end

  local root = app.root
  if name == "test" then
    return { executable }
  end
  if not port then
    return nil
  end

  local entrypoint = vim.fs.relpath(root, app.entrypoint) or app.entrypoint
  local command = {
    executable,
    "run",
    "--reload",
  }
  if environment then
    vim.list_extend(command, {
      "--reload-excludes",
      shiny_reload_excludes .. "," .. environment,
    })
  end
  vim.list_extend(command, { "--port", tostring(port), entrypoint })
  return command
end

---@param name "run"|"test"
---@return string
function tasks.executable(name)
  return tools[name].executable
end

local function missing_tool(name, app)
  messages.show(
    tools[name].executable .. " is not available in " .. app.root .. " or Neovim's PATH",
    vim.log.levels.ERROR
  )
end

local function find_uv_root(app)
  local lock = vim.fs.find("uv.lock", {
    path = app.root,
    upward = true,
    type = "file",
    limit = 1,
  })[1]
  return lock and vim.fs.dirname(lock) or nil
end

local function finish_preparation(root, preparation, status)
  if preparations[root] ~= preparation then
    return true
  end

  preparations[root] = nil
  local constants = require("overseer.constants")
  if status == constants.STATUS.CANCELED then
    messages.show(
      "Environment preparation canceled for " .. vim.fs.basename(root),
      vim.log.levels.WARN
    )
    return true
  end
  if status ~= constants.STATUS.SUCCESS then
    messages.show(
      "Environment preparation failed for " .. vim.fs.basename(root),
      vim.log.levels.ERROR
    )
    return true
  end

  for _, request in pairs(preparation.pending) do
    if find_executable("run", request.app) then
      request.retry()
    else
      missing_tool("run", request.app)
    end
  end
  return true
end

local function prepare(app, retry)
  local root = find_uv_root(app)
  local uv = vim.fn.exepath("uv")
  if not root or not uv or uv == "" then
    missing_tool("run", app)
    return false
  end

  local key = app.id or app.root
  local preparation = preparations[root]
  if preparation then
    preparation.pending[key] = { app = app, retry = retry }
    return true
  end

  local overseer = get_overseer()
  if not overseer then
    return false
  end

  local task = overseer.new_task({
    name = "Tapyr: prepare " .. vim.fs.basename(root),
    cmd = { uv, "sync" },
    cwd = root,
    metadata = { tapyr_prepare = root },
    components = { "default" },
  })
  preparation = {
    pending = {
      [key] = { app = app, retry = retry },
    },
  }
  preparations[root] = preparation

  task:subscribe("on_complete", function(_, status)
    return finish_preparation(root, preparation, status)
  end)
  messages.show("Preparing environment in " .. root)
  if task:start() == false then
    preparations[root] = nil
    messages.show("Could not start environment preparation", vim.log.levels.ERROR)
    return false
  end
  show_task(task)
  return true
end

local function with_shiny(app, retry)
  if find_executable("run", app) then
    return retry()
  end
  return prepare(app, retry)
end

local function listening_ports()
  local used = {}
  if vim.fn.executable("ss") ~= 1 then
    return used
  end

  local result = vim.system({ "ss", "-H", "-ltn" }, { text = true }):wait()
  if result.code ~= 0 then
    return used
  end

  for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
    local address = vim.split(line, "%s+")[4]
    local port = address and tonumber(address:match(":(%d+)$"))
    if port then
      used[port] = true
    end
  end
  return used
end

local function assign_port(app)
  local used = listening_ports()
  local assigned = assigned_ports[app.id]
  if assigned then
    if used[assigned] then
      messages.show("Port " .. assigned .. " is already in use", vim.log.levels.ERROR)
      return nil
    end
    return assigned
  end

  local port = app.port
  if port then
    local owner = reserved_ports[port]
    if used[port] or (owner and owner ~= app.id) then
      messages.show("Port " .. port .. " is already in use", vim.log.levels.ERROR)
      return nil
    end
  else
    for candidate = 8000, 8199 do
      if not used[candidate] and not reserved_ports[candidate] then
        port = candidate
        break
      end
    end
    if not port then
      messages.show("No free Tapyr port found from 8000 to 8199", vim.log.levels.ERROR)
      return nil
    end
  end

  assigned_ports[app.id] = port
  reserved_ports[port] = app.id
  return port
end

local function release_port(app)
  local port = assigned_ports[app.id]
  assigned_ports[app.id] = nil
  if port and reserved_ports[port] == app.id then
    reserved_ports[port] = nil
  end
end

local function new_app_task(app)
  local port = assign_port(app)
  if not port then
    return nil
  end

  local command = tasks.resolve("run", app, port)
  if not command then
    release_port(app)
    missing_tool("run", app)
    return nil
  end

  local overseer = get_overseer()
  if not overseer then
    release_port(app)
    return nil
  end

  return overseer.new_task({
    name = "Tapyr: " .. app.name,
    cmd = command,
    cwd = app.root,
    env = { PYTHONDONTWRITEBYTECODE = "1" },
    metadata = {
      tapyr_app = app.id,
      tapyr_port = port,
    },
    components = { "default" },
  })
end

---@param app TapyrAppDefinition
---@return integer?
function tasks.port(app)
  return assigned_ports[app.id] or app.port
end

local function ensure_app_task(app)
  local task = app_tasks[app.id]
  local created = not task or task:is_disposed()
  if created then
    task = new_app_task(app)
    app_tasks[app.id] = task
  end

  return task, created
end

---@param name "run"|"test"
---@return string
function tasks.describe(name)
  local tool = tools[name]
  if name == "run" then
    return tool.executable .. " run --reload --port <auto> app.py"
  end
  return tool.executable
end

local function run(app, on_started)
  local task = ensure_app_task(app)
  if not task then
    return false
  end

  local constants = require("overseer.constants")

  if task.status == constants.STATUS.PENDING then
    task:start()
  elseif task.status ~= constants.STATUS.RUNNING then
    task:restart(true)
  end

  show_task(task)
  if on_started then
    on_started()
  end
  return true
end

local function restart(app, show_task_list, on_started)
  local task, created = ensure_app_task(app)
  if not task then
    return false
  end

  if created then
    task:start()
  else
    task:restart(true)
  end

  if show_task_list ~= false then
    show_task(task)
  end
  if on_started then
    on_started()
  end
  return true
end

---@param app TapyrAppDefinition
---@param on_started? fun()
---@return boolean
function tasks.run(app, on_started)
  return with_shiny(app, function()
    return run(app, on_started)
  end)
end

---@param app TapyrAppDefinition
---@param show_task_list? boolean
---@param on_started? fun()
---@return boolean
function tasks.restart(app, show_task_list, on_started)
  return with_shiny(app, function()
    return restart(app, show_task_list, on_started)
  end)
end

---@param app TapyrAppDefinition
---@return boolean
function tasks.test(app)
  local command = tasks.resolve("test", app)
  if not command then
    missing_tool("test", app)
    return false
  end

  local overseer = get_overseer()
  if not overseer then
    return false
  end

  local task = overseer.new_task({
    name = "Tapyr: test " .. app.name,
    cmd = command,
    cwd = project.root(app.root),
    env = { PYTHONDONTWRITEBYTECODE = "1" },
    metadata = { tapyr_app = app.id },
    components = {
      { "on_output_quickfix", open_on_match = true, set_diagnostics = true },
      "on_result_diagnostics",
      "default",
    },
  })

  task:start()
  show_task(task)
  return true
end

return tasks
