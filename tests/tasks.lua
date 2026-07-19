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
local function new_task(spec)
  local task = {
    disposed = false,
    restarts = 0,
    starts = 0,
    status = status.PENDING,
    spec = spec,
  }

  function task:get_bufnr()
    return nil
  end

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
  run_action = function()
    error("task output should not open without a buffer")
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

tasks.start("/tmp/start")
assert(created[#created].starts == 1, "start task was not started")
assert(created[#created].spec.cwd == "/tmp/start", "start task used the wrong root")
assert(created[#created].spec.cmd[1] == "/usr/bin/shiny", "start task used the wrong executable")
assert(created[#created].spec.cmd[3] == "--reload", "start task did not enable reload")
assert(
  created[#created].spec.env.PYTHONDONTWRITEBYTECODE == "1",
  "start task allowed bytecode writes"
)

tasks.run("/tmp/run")
local run_task = created[#created]
assert(run_task.starts == 1, "pending task was not started")

run_task.status = "success"
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "completed task was not restarted")

run_task.status = status.RUNNING
tasks.run("/tmp/run")
assert(run_task.restarts == 1, "running task was restarted")

tasks.restart("/tmp/restart")
local restart_task = created[#created]
assert(restart_task.starts == 1, "new restart task was not started")

tasks.restart("/tmp/restart")
assert(restart_task.restarts == 1, "existing task was not restarted")

tasks.test("/tmp/test")
local test_task = created[#created]
assert(test_task.starts == 1, "test task was not started")
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
  return "/usr/bin/" .. command
end
package.loaded.overseer = nil
package.preload.overseer = function()
  error("overseer unavailable")
end

tasks.start("/tmp/missing-overseer")
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
