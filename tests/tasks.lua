local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")

local original_constants = package.loaded["overseer.constants"]
local original_executable = vim.fn.executable
local original_exepath = vim.fn.exepath
local original_overseer = package.loaded.overseer
local original_preload = package.preload.overseer
local original_show = messages.show
local original_system = vim.system

local status = {
  CANCELED = "canceled",
  FAILURE = "failure",
  PENDING = "pending",
  RUNNING = "running",
  SUCCESS = "success",
}

local created = {}
local opened = {}
local function new_task(spec)
  local task = {
    disposed = false,
    id = #created + 1,
    restarts = 0,
    starts = 0,
    status = status.PENDING,
    subscribers = {},
    spec = spec,
  }

  function task:is_disposed()
    return self.disposed
  end

  function task:restart()
    self.restarts = self.restarts + 1
    self.status = status.RUNNING
    return true
  end

  function task:start()
    self.starts = self.starts + 1
    self.status = status.RUNNING
    return true
  end

  function task:subscribe(event, callback)
    self.subscribers[event] = self.subscribers[event] or {}
    self.subscribers[event][#self.subscribers[event] + 1] = callback
  end

  function task:complete(result)
    self.status = result
    for _, callback in ipairs(self.subscribers.on_complete or {}) do
      callback(self, result)
    end
  end

  return task
end

package.loaded.overseer = {
  new_task = function(spec)
    local task = new_task(spec)
    created[#created + 1] = task
    return task
  end,
  open = function(opts)
    opened[#opened + 1] = opts
  end,
}
package.loaded["overseer.constants"] = { STATUS = status }

local project_executables = {}
local system_executables = {
  pytest = "/usr/bin/pytest",
  shiny = "/usr/bin/shiny",
  uv = "/usr/bin/uv",
}
vim.fn.executable = function(command)
  return project_executables[command] and 1 or 0
end
vim.fn.exepath = function(command)
  return system_executables[command] or ""
end

vim.system = function(command)
  assert(command[1] == "ss", "unexpected system command")
  return {
    wait = function()
      return { code = 0, stdout = "" }
    end,
  }
end

local function app(root, name, port)
  return {
    id = root .. "/app.py",
    name = name or vim.fs.basename(root),
    root = root,
    entrypoint = root .. "/app.py",
    port = port,
  }
end

local project_app = app("/tmp/project/apps/demo", "demo")
assert(
  vim.deep_equal(tasks.resolve("run", project_app, 8123), {
    "/usr/bin/shiny",
    "run",
    "--reload",
    "--port",
    "8123",
    "app.py",
  }),
  "run command did not use Shiny reload"
)

local project_shiny = "/tmp/project/.venv/bin/shiny"
project_executables[project_shiny] = true
assert(
  tasks.resolve("run", project_app, 8123)[1] == project_shiny,
  "parent project Shiny was not preferred"
)
project_executables[project_shiny] = nil

local run_app = app("/tmp/run", "run", 49151)
tasks.run(run_app)
local run_task = created[#created]
assert(run_task.starts == 1, "pending task was not started")
assert(opened[#opened].enter == false, "run task took focus")
assert(opened[#opened].focus_task_id == run_task.id, "run task was not selected")
assert(opened[#opened].direction == nil, "run task overrode the Overseer direction")
assert(run_task.spec.name == "Tapyr: run", "run task name did not identify the app")
assert(run_task.spec.cmd[5] == "49151", "configured app port was not used")
assert(run_task.spec.metadata.tapyr_app == run_app.id, "task lost its app identity")

run_task.status = "success"
tasks.run(run_app)
assert(run_task.restarts == 1, "completed task was not restarted")

run_task.status = status.RUNNING
tasks.run(run_app)
assert(run_task.restarts == 1, "running task was restarted")

run_task.disposed = true
tasks.run(run_app)
local replacement_task = created[#created]
assert(replacement_task ~= run_task, "disposed task was retained")
assert(replacement_task.starts == 1, "replacement task was not started")

local opened_before_restart = #opened
local restart_app = app("/tmp/restart", "restart", 49152)
tasks.restart(restart_app, false)
local restart_task = created[#created]
assert(restart_task.starts == 1, "new restart task was not started")
assert(#opened == opened_before_restart, "silent restart opened the Overseer task list")
assert(restart_task.spec.cwd == "/tmp/restart", "restart task used the wrong root")
assert(restart_task.spec.cmd[1] == "/usr/bin/shiny", "restart task used the wrong executable")
assert(restart_task.spec.cmd[3] == "--reload", "restart task did not enable reload")
assert(restart_task.spec.env.PYTHONDONTWRITEBYTECODE == "1", "restart task allowed bytecode writes")

tasks.restart(restart_app)
assert(restart_task.restarts == 1, "existing task was not restarted")
assert(opened[#opened].enter == false, "Overseer task list took focus")
assert(opened[#opened].focus_task_id == restart_task.id, "restarted task was not selected")
assert(opened[#opened].direction == nil, "restart overrode the Overseer direction")

local test_app = app("/tmp/test", "test")
tasks.test(test_app)
local test_task = created[#created]
assert(test_task.starts == 1, "test task was not started")
assert(opened[#opened].enter == false, "test task took focus")
assert(opened[#opened].focus_task_id == test_task.id, "test task was not selected")
assert(opened[#opened].direction == nil, "test task overrode the Overseer direction")
assert(test_task.spec.cwd == "/tmp/test", "test task used the wrong root")
assert(test_task.spec.cmd[1] == "/usr/bin/pytest", "test task used the wrong command")
assert(test_task.spec.env.PYTHONDONTWRITEBYTECODE == "1", "test task allowed bytecode writes")
assert(test_task.spec.name == "Tapyr: test test", "test task name did not identify the app")

local messages_seen = {}
messages.show = function(message)
  messages_seen[#messages_seen + 1] = message
end

local uv_root = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "uv-project")
local uv_app = app(vim.fs.joinpath(uv_root, "apps", "demo"), "uv app", 49153)
system_executables.shiny = nil

local created_before_prepare = #created
local messages_before_prepare = #messages_seen
assert(tasks.run(uv_app), "missing Shiny did not start environment preparation")
local prepare_task = created[#created]
assert(#created == created_before_prepare + 1, "environment preparation created extra tasks")
assert(prepare_task.spec.name == "Tapyr: prepare uv-project", "preparation task name changed")
assert(vim.deep_equal(prepare_task.spec.cmd, { "/usr/bin/uv", "sync" }), "uv sync command changed")
assert(prepare_task.spec.cwd == uv_root, "uv sync used the wrong project root")
assert(prepare_task.spec.metadata.tapyr_prepare == uv_root, "uv project identity was lost")
assert(opened[#opened].enter == false, "environment preparation took focus")
assert(opened[#opened].focus_task_id == prepare_task.id, "preparation task was not selected")
assert(#messages_seen == messages_before_prepare + 1, "preparation notification was duplicated")

local prepared_started = false
assert(
  tasks.restart(uv_app, false, function()
    prepared_started = true
  end),
  "repeated restart rejected active preparation"
)
assert(#created == created_before_prepare + 1, "repeated action created another uv sync task")
assert(#messages_seen == messages_before_prepare + 1, "repeated action repeated the notification")

local uv_shiny = vim.fs.joinpath(uv_root, ".venv", "bin", "shiny")
project_executables[uv_shiny] = true
prepare_task:complete(status.SUCCESS)
local prepared_app_task = created[#created]
assert(#created == created_before_prepare + 2, "successful preparation did not start the app")
assert(prepared_app_task.spec.cmd[1] == uv_shiny, "prepared Shiny executable was not used")
assert(prepared_app_task.starts == 1, "prepared app was not started")
assert(prepared_app_task.restarts == 0, "repeated actions started the prepared app more than once")
assert(prepared_started, "prepared app did not complete the restart handoff")

project_executables[uv_shiny] = nil
local created_before_failure = #created
assert(tasks.run(uv_app), "second preparation did not start")
local failed_prepare_task = created[#created]
failed_prepare_task:complete(status.FAILURE)
assert(#created == created_before_failure + 1, "failed preparation started an app")
assert(
  messages_seen[#messages_seen] == "Environment preparation failed for uv-project",
  "failed preparation was not reported"
)

local created_before_cancel = #created
assert(tasks.run(uv_app), "canceled preparation did not start")
local canceled_prepare_task = created[#created]
canceled_prepare_task:complete(status.CANCELED)
assert(#created == created_before_cancel + 1, "canceled preparation started an app")
assert(
  messages_seen[#messages_seen] == "Environment preparation canceled for uv-project",
  "canceled preparation was not reported"
)

system_executables.uv = nil
assert(not tasks.run(uv_app), "missing uv started environment preparation")
assert(
  messages_seen[#messages_seen]:find("shiny is not available", 1, true),
  "missing uv did not retain the Shiny error"
)
system_executables.uv = "/usr/bin/uv"
system_executables.shiny = "/usr/bin/shiny"

vim.system = function()
  return {
    wait = function()
      return {
        code = 0,
        stdout = "LISTEN 0 4096 127.0.0.1:8000 0.0.0.0:*\n",
      }
    end,
  }
end
project_executables.ss = true
local auto_app = app("/tmp/auto", "auto")
tasks.run(auto_app)
local auto_task = created[#created]
assert(auto_task.spec.cmd[5] == "8001", "automatic port did not skip a listener")

local created_before_collision = #created
tasks.run(app("/tmp/collision", "collision", 8000))
assert(#created == created_before_collision, "port collision created a task")
assert(
  messages_seen[#messages_seen] == "Port 8000 is already in use",
  "port collision was not reported"
)
project_executables.ss = nil

vim.system = function()
  return {
    wait = function()
      return { code = 0, stdout = "" }
    end,
  }
end
system_executables.shiny = nil
tasks.run(app("/tmp/missing-shiny", "missing shiny", 49153))
assert(
  messages_seen[#messages_seen]:find("shiny is not available", 1, true),
  "missing Shiny error was not shown"
)

system_executables.shiny = "/usr/bin/shiny"
system_executables.pytest = nil
tasks.test(app("/tmp/missing-pytest", "missing pytest"))
assert(
  messages_seen[#messages_seen]:find("pytest is not available", 1, true),
  "missing pytest error was not shown"
)

system_executables.pytest = "/usr/bin/pytest"
package.loaded.overseer = nil
package.preload.overseer = function()
  error("overseer unavailable")
end

tasks.restart(app("/tmp/missing-overseer", "missing overseer", 49154))
assert(
  messages_seen[#messages_seen] == "Overseer is required to run apps and tests",
  "missing Overseer error was not shown"
)

messages.show = original_show
vim.fn.executable = original_executable
vim.fn.exepath = original_exepath
package.loaded.overseer = original_overseer
package.loaded["overseer.constants"] = original_constants
package.preload.overseer = original_preload
vim.system = original_system
