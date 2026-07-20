local python = {
  id = "python",
  label = "Python",
}

local messages = require("shiny.messages")
local project = require("shiny.project")
local preparations = {}
local reload_excludes = ".*,*.py[cod],__pycache__,env,venv"

local executables = {
  run = "shiny",
  test = "pytest",
}

---@param path string
---@return boolean
local function is_app(path)
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end

  for _, line in ipairs(vim.fn.readfile(path, "", 200)) do
    if
      line:match("^%s*from%s+shiny[%s%.]")
      or line:match("^%s*import%s+shiny%s*$")
      or line:match("^%s*import%s+shiny[%s,]")
    then
      return true
    end
  end
  return false
end

---@param action "run"|"test"
---@param app ShinyAppDefinition
---@return string?, string?
local function find_executable(action, app)
  local executable = executables[action]
  local directory = app.root
  while directory do
    local environment = vim.fs.joinpath(directory, ".venv")
    local candidate = vim.fs.joinpath(environment, "bin", executable)
    if vim.fn.executable(candidate) == 1 then
      return candidate, environment
    end
    local parent = vim.fs.dirname(directory)
    if parent == directory then
      break
    end
    directory = parent
  end

  local path = vim.fn.exepath(executable)
  if path and path ~= "" then
    return path
  end
end

local function missing(action, app)
  return executables[action] .. " is not available in " .. app.root .. " or Neovim's PATH"
end

---@param start string
---@return ShinyAppDefinition?
function python.detect(start)
  local entrypoint = project.find_file(start, "app.py")
  if entrypoint and is_app(entrypoint) then
    local root = vim.fs.dirname(entrypoint)
    return project.definition("python", root, entrypoint)
  end
end

---@param app ShinyAppDefinition
---@param action "run"|"test"
---@param context table
---@return table?, string?
function python.task(app, action, context)
  if action == "run" and not context.port then
    return nil, "A port is required to run " .. app.name
  end

  local override = app.commands and app.commands[action]
  if override then
    local env = { PYTHONDONTWRITEBYTECODE = "1" }
    if action == "run" then
      env.SHINY_PORT = tostring(context.port)
    end
    return {
      cmd = vim.deepcopy(override),
      cwd = action == "test" and project.python_root(app.root) or app.root,
      env = env,
    }
  end

  local executable, environment = find_executable(action, app)
  if not executable then
    return nil, missing(action, app)
  end
  if action == "test" then
    return {
      cmd = { executable },
      cwd = project.python_root(app.root),
      env = { PYTHONDONTWRITEBYTECODE = "1" },
    }
  end
  local entrypoint = vim.fs.relpath(app.root, app.entrypoint) or app.entrypoint
  local command = { executable, "run", "--reload" }
  if environment then
    vim.list_extend(command, {
      "--reload-excludes",
      reload_excludes .. "," .. environment,
    })
  end
  vim.list_extend(command, { "--port", tostring(context.port), entrypoint })

  return {
    cmd = command,
    cwd = app.root,
    env = { PYTHONDONTWRITEBYTECODE = "1" },
  }
end

---@param action "run"|"test"
---@return string
function python.describe(action)
  if action == "run" then
    return "shiny run --reload --port <auto> app.py"
  end
  return "pytest"
end

local function uv_root(app)
  local lock = vim.fs.find("uv.lock", {
    path = app.root,
    upward = true,
    type = "file",
    limit = 1,
  })[1]
  return lock and vim.fs.dirname(lock) or nil
end

---@param app ShinyAppDefinition
---@param action "run"|"test"
---@param retry fun()
---@return boolean
function python.prepare(app, action, retry)
  if action ~= "run" then
    messages.show(missing(action, app), vim.log.levels.ERROR)
    return false
  end

  local root = uv_root(app)
  local uv = vim.fn.exepath("uv")
  if not root or not uv or uv == "" then
    messages.show(missing(action, app), vim.log.levels.ERROR)
    return false
  end

  local preparation = preparations[root]
  if preparation then
    preparation.pending[app.id] = { app = app, retry = retry }
    return true
  end

  local task = require("shiny.overseer").new({
    name = "Shiny: prepare " .. vim.fs.basename(root),
    cmd = { uv, "sync" },
    cwd = root,
    metadata = { shiny_prepare = root },
    components = { "default" },
  })
  if not task then
    return false
  end

  preparation = {
    pending = {
      [app.id] = { app = app, retry = retry },
    },
  }
  preparations[root] = preparation

  task:subscribe("on_complete", function(_, status)
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
        messages.show(missing("run", request.app), vim.log.levels.ERROR)
      end
    end
    return true
  end)

  messages.show("Preparing environment in " .. root)
  if task:start() == false then
    preparations[root] = nil
    messages.show("Could not start environment preparation", vim.log.levels.ERROR)
    return false
  end
  require("shiny.overseer").show(task)
  return true
end

---@return table[]
function python.health()
  local checks = {}
  for _, action in ipairs({ "run", "test" }) do
    local executable = executables[action]
    checks[#checks + 1] = {
      ok = vim.fn.exepath(executable) ~= "",
      success = executable .. " is available",
      failure = executable
        .. " is not on PATH; a project .venv may still provide Python "
        .. action,
    }
  end
  checks[#checks + 1] = {
    ok = vim.fn.executable("ss") == 1,
    success = "ss is available for external Python app discovery",
    failure = "ss is unavailable; managed apps still work",
  }
  checks[#checks + 1] = {
    ok = vim.fn.isdirectory("/proc") == 1,
    success = "/proc is available for external Python app details",
    failure = "/proc is unavailable; managed apps still work",
  }
  return checks
end

return python
