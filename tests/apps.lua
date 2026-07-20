local apps = require("shiny.apps")
local messages = require("shiny.messages")
local tasks = require("shiny.tasks")

local original_defer_fn = vim.defer_fn
local original_find_external = apps.find_external
local original_inspect = apps.inspect
local original_jobstart = vim.fn.jobstart
local original_open = vim.ui.open
local original_show = messages.show
local original_restart = tasks.restart
local original_restart_managed = tasks.restart_managed
local original_sessions = tasks.sessions
local original_stop_managed = tasks.stop_managed
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

local managed_stopped
tasks.stop_managed = function(id)
  managed_stopped = id
  return true
end
assert(
  apps.stop({
    id = "golem:/tmp/managed",
    managed = true,
    name = "managed",
  }),
  "managed app was not stopped"
)
assert(managed_stopped == "golem:/tmp/managed", "managed stop bypassed the task owner")
assert(messages_seen[#messages_seen] == "Stopped managed", "managed stop message changed")

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
  id = "python:/tmp/current/app.py",
  backend = "python",
  name = "current",
  root = "/tmp/current",
  entrypoint = "/tmp/current/app.py",
  commands = {},
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

local managed_started = false
tasks.restart_managed = function(id, show_task_list, on_started)
  assert(id == "golem:/tmp/managed", "managed restart lost its app identity")
  assert(show_task_list == false, "managed panel restart opened the task list")
  on_started()
  return true
end
assert(
  apps.restart({
    session = {
      id = "golem:/tmp/managed",
      managed = true,
    },
  }, function()
    managed_started = true
  end),
  "managed untracked app was not restarted"
)
assert(managed_started, "managed restart callback was not forwarded")

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

local managed_session = {
  id = current_definition.id,
  backend = "python",
  name = "current",
  cwd = current_definition.root,
  port = 8000,
  start_time = "overseer:1:1",
  launch = "shiny run --reload --port <auto> app.py",
  managed = true,
}
tasks.sessions = function()
  return { managed_session }
end
apps.find_external = function()
  return {
    {
      id = current_definition.id,
      backend = "python",
      pid = 201,
      argv = { "shiny", "run", "--reload", "--port", "8000", "app.py" },
      cwd = current_definition.root,
      port = 8000,
      start_time = "2001",
      launch = "shiny run --reload --port 8000 app.py",
    },
    {
      id = current_definition.id,
      backend = "python",
      pid = 202,
      argv = { "shiny", "run", "--port", "8001", "app.py" },
      cwd = current_definition.root,
      port = 8001,
      start_time = "2002",
      launch = "shiny run --port 8001 app.py",
    },
  }
end
local found = apps.find()
assert(#found == 2, "managed reconciliation discarded another app instance")
assert(found[1] == managed_session, "managed session ownership changed")
assert(found[1].pid == 201, "managed session did not receive its process PID")
assert(
  found[1].launch == "shiny run --reload --port 8000 app.py",
  "managed session did not receive the concrete process command"
)
assert(found[1].start_time == "overseer:1:1", "process discovery replaced managed identity")
assert(found[2].pid == 202, "distinct external instance was discarded")

local definitions = {
  current_definition,
  {
    id = "python:/tmp/stopped/app.py",
    backend = "python",
    name = "stopped",
    root = "/tmp/stopped",
    entrypoint = "/tmp/stopped/app.py",
    commands = {},
  },
}
local running = {
  {
    id = current_definition.id,
    backend = "python",
    name = "current",
    cwd = current_definition.root,
    port = 8000,
  },
  {
    id = "python:/tmp/external/app.py",
    backend = "python",
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
apps.find_external = original_find_external
apps.inspect = original_inspect
messages.show = original_show
tasks.restart = original_restart
tasks.restart_managed = original_restart_managed
tasks.sessions = original_sessions
tasks.stop_managed = original_stop_managed
vim.defer_fn = original_defer_fn
vim.fn.jobstart = original_jobstart
vim.system = original_system
vim.ui.open = original_open
