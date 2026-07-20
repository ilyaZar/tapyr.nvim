local tasks = {}

local backend = require("shiny.backend")
local messages = require("shiny.messages")
local overseer = require("shiny.overseer")
local app_tasks = {}
local assigned_ports = {}
local reserved_ports = {}

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

---@param app ShinyAppDefinition
---@return integer?
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
      messages.show("No free Shiny port found from 8000 to 8199", vim.log.levels.ERROR)
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

local function provider(app)
  local value = backend.get(app.backend)
  if not value then
    messages.show("Unknown Shiny backend: " .. tostring(app.backend), vim.log.levels.ERROR)
  end
  return value
end

local function task_spec(app, action, port)
  local app_backend = provider(app)
  if not app_backend then
    return nil, nil, nil
  end

  local spec, error_message = app_backend.task(app, action, { port = port })
  return spec, error_message, app_backend
end

local function create_run_task(app, retry)
  local port = assign_port(app)
  if not port then
    return nil, false
  end

  local spec, error_message, app_backend = task_spec(app, "run", port)
  if not spec then
    if app_backend and app_backend.prepare then
      local preparing = app_backend.prepare(app, "run", retry)
      if preparing then
        release_port(app)
        return nil, true
      end
    elseif error_message then
      messages.show(error_message, vim.log.levels.ERROR)
    end
    release_port(app)
    return nil, false
  end

  local task = overseer.new({
    name = "Shiny: " .. app.name,
    cmd = spec.cmd,
    cwd = spec.cwd,
    env = spec.env,
    metadata = {
      shiny_app = app.id,
      shiny_backend = app.backend,
      shiny_port = port,
    },
    components = { "default" },
  })
  if not task then
    release_port(app)
    return nil, false
  end
  return task, false
end

local function ensure_app_task(app, retry)
  local managed = app_tasks[app.id]
  local created = not managed or managed.task:is_disposed()
  if created then
    local preparing
    local task
    task, preparing = create_run_task(app, retry)
    if task then
      app_tasks[app.id] = {
        app = vim.deepcopy(app),
        generation = 1,
        task = task,
      }
    end
    return task, true, preparing
  end
  return managed.task, false, false
end

local function ensure_backend(app, retry)
  local spec, error_message, app_backend =
    task_spec(app, "run", tasks.port(app) or app.port or 8000)
  if spec then
    return true, false
  end
  if app_backend and app_backend.prepare and app_backend.prepare(app, "run", retry) then
    return false, true
  end
  if error_message and not (app_backend and app_backend.prepare) then
    messages.show(error_message, vim.log.levels.ERROR)
  end
  return false, false
end

---@param app ShinyAppDefinition
---@return integer?
function tasks.port(app)
  return assigned_ports[app.id] or app.port
end

local function start(app, force_restart, show_task_list, on_started)
  local retry = function()
    start(app, force_restart, show_task_list, on_started)
  end
  local available, preparing = ensure_backend(app, retry)
  if preparing then
    return true
  end
  if not available then
    return false
  end

  local task, created, preparing = ensure_app_task(app, retry)
  if preparing then
    return true
  end
  if not task then
    return false
  end

  local constants = require("overseer.constants")
  if created or (not force_restart and task.status == constants.STATUS.PENDING) then
    task:start()
  elseif force_restart or task.status ~= constants.STATUS.RUNNING then
    app_tasks[app.id].generation = app_tasks[app.id].generation + 1
    task:restart(true)
  end
  if show_task_list ~= false then
    overseer.show(task)
  end
  if on_started then
    on_started()
  end
  return true
end

---@param app ShinyAppDefinition
---@param on_started? fun()
---@return boolean
function tasks.run(app, on_started)
  return start(app, false, true, on_started)
end

---@param app ShinyAppDefinition
---@param show_task_list? boolean
---@param on_started? fun()
---@return boolean
function tasks.restart(app, show_task_list, on_started)
  return start(app, true, show_task_list, on_started)
end

---@param id string
---@param show_task_list? boolean
---@param on_started? fun()
---@return boolean
function tasks.restart_managed(id, show_task_list, on_started)
  local managed = app_tasks[id]
  if not managed or managed.task:is_disposed() then
    return false
  end
  return tasks.restart(managed.app, show_task_list, on_started)
end

---@param app ShinyAppDefinition
---@return boolean
function tasks.test(app)
  local spec, error_message = task_spec(app, "test")
  if not spec then
    if error_message then
      messages.show(error_message, vim.log.levels.ERROR)
    end
    return false
  end

  local task = overseer.new({
    name = "Shiny: test " .. app.name,
    cmd = spec.cmd,
    cwd = spec.cwd,
    env = spec.env,
    metadata = {
      shiny_app = app.id,
      shiny_backend = app.backend,
    },
    components = {
      { "on_output_quickfix", open_on_match = true, set_diagnostics = true },
      "on_result_diagnostics",
      "default",
    },
  })
  if not task then
    return false
  end
  task:start()
  overseer.show(task)
  return true
end

---@param id string
---@return boolean
function tasks.stop_managed(id)
  local managed = app_tasks[id]
  if not managed or managed.task:is_disposed() then
    return false
  end
  local result = managed.task:stop()
  return result ~= false
end

local function browser_url(port)
  return "http://127.0.0.1:" .. port
end

---@return ShinyRunningApp[]
function tasks.sessions()
  local sessions = {}
  local ok, constants = pcall(require, "overseer.constants")
  if not ok then
    return sessions
  end

  for _, managed in pairs(app_tasks) do
    local task = managed.task
    if not task:is_disposed() and task.status == constants.STATUS.RUNNING then
      local app = managed.app
      local port = assigned_ports[app.id]
      sessions[#sessions + 1] = {
        id = app.id,
        backend = app.backend,
        entrypoint = app.entrypoint,
        name = app.name,
        cwd = app.root,
        port = port,
        start_time = table.concat({
          "overseer",
          tostring(task.id),
          tostring(managed.generation),
        }, ":"),
        url = browser_url(port),
        launch = backend.get(app.backend).describe("run"),
        managed = true,
      }
    end
  end

  table.sort(sessions, function(left, right)
    return left.id < right.id
  end)
  return sessions
end

return tasks
