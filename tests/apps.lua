local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")

local original_defer_fn = vim.defer_fn
local original_inspect = apps.inspect
local original_jobstart = vim.fn.jobstart
local original_open = vim.ui.open
local original_show = messages.show
local original_restart = tasks.restart
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
assert(
  not apps.is_shiny_command({ "uvicorn", "shiny_service:app" }),
  "unrelated command was accepted"
)
assert(apps.launch_label({
  "/tmp/project/.venv/bin/python",
  "/tmp/project/.venv/bin/shiny",
  "run",
  "--reload",
  "--reload-excludes",
  ".*,*.py[cod],__pycache__,env,venv,/tmp/project/.venv",
  "/tmp/project/app.py",
}) == "shiny run --reload app.py", "direct Shiny command label kept paths")
assert(apps.launch_label({
  "/usr/bin/uv",
  "run",
  "/tmp/project/.venv/bin/shiny",
  "run",
  "--reload",
  "app.py",
}) == "uv run shiny run --reload app.py", "uv command label lost its launcher")
assert(apps.launch_label({ "python", "app.py" }) == "-", "unrelated command received a label")
assert(
  apps.entrypoint({ "shiny", "run", "--reload", "/tmp/project/main.py:app" }, "/tmp/project")
    == "/tmp/project/main.py",
  "absolute Shiny entrypoint was not detected"
)
assert(
  apps.entrypoint({ "shiny", "run", "--reload", "app.py" }, "/tmp/project") == "/tmp/project/app.py",
  "relative Shiny entrypoint was not detected"
)

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

apps.restart(nil)
assert(messages_seen[#messages_seen] == "Select an app first", "missing app warning was not shown")

vim.defer_fn = function(callback)
  callback()
end

local started
local stop_result = true
apps.stop = function()
  return stop_result
end
tasks.restart = function(root, show_task_list, on_started)
  started = {
    app = root,
    on_started = on_started,
    show_task_list = show_task_list,
  }
  return true
end

local current_definition = {
  id = "/tmp/current/app.py",
  name = "current",
  root = "/tmp/current",
  entrypoint = "/tmp/current/app.py",
}
local tracked_started = false
apps.restart({
  definition = current_definition,
  session = { pid = 103 },
}, function()
  tracked_started = true
end)
assert(started.app == current_definition, "tracked app was not restarted")
assert(started.show_task_list == false, "panel restart opened the Overseer task list")
assert(not tracked_started, "tracked restart callback ran before the task started")
started.on_started()
assert(tracked_started, "tracked restart callback was not forwarded")

local external_started = false
apps.restart({
  name = "other",
  root = "/tmp/other",
  session = { pid = 104 },
})
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
  name = "other",
  root = "/tmp/other",
  session = {
    pid = 105,
    cwd = "/tmp/other",
    argv = { "shiny", "run", "app.py" },
  },
})
assert(jobs_started == 0, "restart continued after a failed stop")

stop_result = true
vim.fn.jobstart = function()
  jobs_started = jobs_started + 1
  return 1
end
apps.restart({
  name = "other",
  root = "/tmp/other",
  session = {
    pid = 106,
    cwd = "/tmp/other",
    argv = { "shiny", "run", "app.py" },
    launch = "shiny run app.py",
  },
}, function()
  external_started = true
end)
assert(jobs_started == 1, "external app was not restarted")
assert(external_started, "external restart callback was not called")

vim.fn.jobstart = function()
  return 0
end
apps.restart({
  name = "other",
  root = "/tmp/other",
  session = {
    pid = 107,
    argv = { "shiny", "run", "app.py" },
  },
})
assert(
  messages_seen[#messages_seen]:find("Could not restart", 1, true),
  "restart error was not shown"
)

local definitions = {
  current_definition,
  {
    id = "/tmp/stopped/app.py",
    name = "stopped",
    root = "/tmp/stopped",
    entrypoint = "/tmp/stopped/app.py",
  },
}
local running = {
  {
    id = current_definition.id,
    name = "current",
    cwd = current_definition.root,
    port = 8000,
  },
  {
    id = "/tmp/external/app.py",
    name = "external",
    cwd = "/tmp/external",
    port = 8001,
  },
}
local rows = apps.merge(definitions, running)
assert(#rows == 3, "tracked and external apps were not merged")
assert(rows[1].state == "running", "running tracked app state changed")
assert(rows[1].session == running[1], "running tracked session was lost")
assert(rows[2].state == "stopped", "stopped tracked app state changed")
assert(rows[3].state == "running", "untracked live app was not marked running")

local opened_url
vim.ui.open = function(url)
  opened_url = url
end
apps.open_in_browser("http://127.0.0.1:8000")
assert(opened_url == "http://127.0.0.1:8000", "vim.ui.open was not used")

apps.stop = original_stop
apps.inspect = original_inspect
messages.show = original_show
tasks.restart = original_restart
vim.defer_fn = original_defer_fn
vim.fn.jobstart = original_jobstart
vim.system = original_system
vim.ui.open = original_open
