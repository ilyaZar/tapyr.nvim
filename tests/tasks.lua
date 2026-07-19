local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")

local original_constants = package.loaded["overseer.constants"]
local original_executable = vim.fn.executable
local original_exepath = vim.fn.exepath
local original_overseer = package.loaded.overseer
local original_preload = package.preload.overseer
local original_show = messages.show

local status = {
  PENDING = "pending",
  RUNNING = "running",
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
    spec = spec,
  }

  function task:is_disposed()
    return self.disposed
  end

  function task:restart()
    self.restarts = self.restarts + 1
    self.status = status.RUNNING
  end

  function task:start()
    self.starts = self.starts + 1
    self.status = status.RUNNING
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
vim.fn.executable = function(command)
  return project_executables[command] and 1 or 0
end
vim.fn.exepath = function(command)
  return "/usr/bin/" .. command
end

assert(vim.deep_equal(tasks.resolve("run", "/tmp/project"), {
  "/usr/bin/shiny",
  "run",
  "--reload",
  "app.py",
}), "run command did not use Shiny reload")

local project_shiny = "/tmp/project/.venv/bin/shiny"
project_executables[project_shiny] = true
assert(tasks.resolve("run", "/tmp/project")[1] == project_shiny, "project Shiny was not preferred")
project_executables[project_shiny] = nil

tasks.run("/tmp/run")
local run_task = created[#created]
assert(run_task.starts == 1, "pending task was not started")
assert(opened[#opened].focus_task_id == run_task.id, "run task was not selected")

run_task.status = "success"
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "completed task was not restarted")

run_task.status = status.RUNNING
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "running task was restarted")

local opened_before_restart = #opened
tasks.restart("/tmp/restart", false)
local restart_task = created[#created]
assert(restart_task.starts == 1, "new restart task was not started")
assert(#opened == opened_before_restart, "silent restart opened the Overseer task list")
assert(restart_task.spec.cwd == "/tmp/restart", "restart task used the wrong root")
assert(restart_task.spec.cmd[1] == "/usr/bin/shiny", "restart task used the wrong executable")
assert(restart_task.spec.cmd[3] == "--reload", "restart task did not enable reload")
assert(
  restart_task.spec.env.PYTHONDONTWRITEBYTECODE == "1",
  "restart task allowed bytecode writes"
)

tasks.restart("/tmp/restart")
assert(restart_task.restarts == 1, "existing task was not restarted")
assert(opened[#opened].enter == false, "Overseer task list took focus")
assert(opened[#opened].focus_task_id == restart_task.id, "restarted task was not selected")

tasks.test("/tmp/test")
local test_task = created[#created]
assert(test_task.starts == 1, "test task was not started")
assert(opened[#opened].focus_task_id == test_task.id, "test task was not selected")
assert(test_task.spec.cwd == "/tmp/test", "test task used the wrong root")
assert(test_task.spec.cmd[1] == "/usr/bin/pytest", "test task used the wrong command")
assert(test_task.spec.env.PYTHONDONTWRITEBYTECODE == "1", "test task allowed bytecode writes")

local messages_seen = {}
messages.show = function(message)
  messages_seen[#messages_seen + 1] = message
end

vim.fn.exepath = function()
  return ""
end
tasks.run("/tmp/missing-shiny")
assert(
  messages_seen[#messages_seen]:find("shiny is not available", 1, true),
  "missing Shiny error was not shown"
)

vim.fn.exepath = function(command)
  if command == "pytest" then
    return ""
  end
  return "/usr/bin/" .. command
end
tasks.test("/tmp/missing-pytest")
assert(
  messages_seen[#messages_seen]:find("pytest is not available", 1, true),
  "missing pytest error was not shown"
)

vim.fn.exepath = function(command)
  return "/usr/bin/" .. command
end
package.loaded.overseer = nil
package.preload.overseer = function()
  error("overseer unavailable")
end

tasks.restart("/tmp/missing-overseer")
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
