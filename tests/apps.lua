local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")

local original_defer_fn = vim.defer_fn
local original_executable = vim.fn.executable
local original_inspect = apps.inspect
local original_jobstart = vim.fn.jobstart
local original_open = vim.ui.open
local original_show = messages.show
local original_start = tasks.start
local original_stop = apps.stop
local original_system = vim.system

local messages_seen = {}
messages.show = function(message)
  messages_seen[#messages_seen + 1] = message
end

local kill_code = 0
local kills = 0
vim.system = function(command)
  assert(command[1] == "kill", "unexpected system command")
  kills = kills + 1
  return {
    wait = function()
      return { code = kill_code }
    end,
  }
end

assert(not apps.stop(nil), "missing PID was stopped")

local current_process = {
  pid = 101,
  argv = { "/tmp/project/.venv/bin/shiny", "run", "--reload", "app.py" },
  command = "/tmp/project/.venv/bin/shiny run --reload app.py",
  cwd = "/tmp/project",
  start_time = "1001",
}
apps.inspect = function()
  return current_process
end

assert(apps.is_shiny_command({ "shiny", "run", "app.py" }), "direct Shiny command was rejected")
assert(
  apps.is_shiny_command({ "python", "/tmp/.venv/bin/shiny", "run", "app.py" }),
  "Python Shiny command was rejected"
)
assert(not apps.is_shiny_command({ "python", "app.py" }), "generic app.py command was accepted")
assert(not apps.is_shiny_command({ "uvicorn", "shiny_service:app" }), "unrelated command was accepted")

assert(apps.stop(current_process), "valid app was not stopped")
assert(kills == 1, "valid app did not reach kill")

local stale_process = vim.deepcopy(current_process)
stale_process.start_time = "1000"
assert(not apps.stop(stale_process), "stale app identity was stopped")
assert(kills == 1, "stale app reached kill")

local unrelated_process = vim.deepcopy(current_process)
unrelated_process.argv = { "python", "app.py" }
apps.inspect = function()
  return unrelated_process
end
assert(not apps.stop(current_process), "unrelated process was stopped")
assert(kills == 1, "unrelated process reached kill")

apps.inspect = function()
  return current_process
end
kill_code = 1
assert(not apps.stop(current_process), "failed kill was reported as successful")

apps.restart(nil, "/tmp/current")
assert(messages_seen[#messages_seen] == "Select an app first", "missing app warning was not shown")

vim.defer_fn = function(callback)
  callback()
end

local started
local stop_result = true
apps.stop = function()
  return stop_result
end
tasks.start = function(root, open_output)
  started = {
    root = root,
    open_output = open_output,
  }
end

apps.restart({ pid = 103, project = "/tmp/current" }, "/tmp/current")
assert(started.root == "/tmp/current", "current project was not restarted")
assert(started.open_output == false, "panel restart opened task output")

apps.restart({ pid = 104, project = "/tmp/other" }, "/tmp/current")
assert(
  messages_seen[#messages_seen] == "Cannot determine how this app was started",
  "missing command warning was not shown"
)

stop_result = false
local jobs_started = 0
vim.fn.jobstart = function()
  jobs_started = jobs_started + 1
  return 1
end
apps.restart({
  pid = 105,
  project = "/tmp/other",
  cwd = "/tmp/other",
  argv = { "shiny", "run", "app.py" },
}, "/tmp/current")
assert(jobs_started == 0, "restart continued after a failed stop")

stop_result = true
vim.fn.jobstart = function()
  jobs_started = jobs_started + 1
  return 1
end
apps.restart({
  pid = 106,
  project = "/tmp/other",
  cwd = "/tmp/other",
  argv = { "shiny", "run", "app.py" },
  command = "shiny run app.py",
}, "/tmp/current")
assert(jobs_started == 1, "external app was not restarted")

vim.fn.jobstart = function()
  return 0
end
apps.restart({
  pid = 107,
  project = "/tmp/other",
  argv = { "shiny", "run", "app.py" },
}, "/tmp/current")
assert(
  messages_seen[#messages_seen]:find("Could not restart", 1, true),
  "restart error was not shown"
)

local opened_url
vim.ui.open = function(url)
  opened_url = url
end
apps.open_in_browser("http://127.0.0.1:8000")
assert(opened_url == "http://127.0.0.1:8000", "vim.ui.open was not used")

vim.ui.open = nil
vim.fn.executable = function(command)
  return command == "xdg-open" and 1 or 0
end
vim.fn.jobstart = function(command)
  opened_url = command[2]
  return 1
end
apps.open_in_browser("http://127.0.0.1:8001")
assert(opened_url == "http://127.0.0.1:8001", "xdg-open fallback was not used")

vim.fn.executable = function()
  return 0
end
apps.open_in_browser("http://127.0.0.1:8002")
assert(
  messages_seen[#messages_seen]:find("No browser command", 1, true),
  "missing browser warning was not shown"
)

apps.stop = original_stop
apps.inspect = original_inspect
messages.show = original_show
tasks.start = original_start
vim.defer_fn = original_defer_fn
vim.fn.executable = original_executable
vim.fn.jobstart = original_jobstart
vim.system = original_system
vim.ui.open = original_open
