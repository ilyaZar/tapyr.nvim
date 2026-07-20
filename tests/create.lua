local create = require("shiny.create")
local messages = require("shiny.messages")

local original_filereadable = vim.fn.filereadable
local original_fs_stat = vim.uv.fs_stat
local original_input = vim.ui.input
local original_mkdir = vim.fn.mkdir
local original_run = create.run
local original_schedule = vim.schedule
local original_show = messages.show
local original_system = vim.system

assert(
  vim.deep_equal(create.command("Appsilon/tapyr-template", "/tmp/new-app"), {
    "git",
    "clone",
    "--depth=1",
    "https://github.com/Appsilon/tapyr-template.git",
    "/tmp/new-app",
  }),
  "GitHub shorthand did not produce a shallow clone"
)

local source = vim.fn.tempname()
vim.fn.mkdir(source, "p")
assert(
  vim.deep_equal(create.command(source, "/tmp/new-app"), {
    "cp",
    "-R",
    source .. "/.",
    "/tmp/new-app",
  }),
  "local template did not produce a copy command"
)
assert(
  not create.command("https://example.com/template", "/tmp/new-app"),
  "unknown source was accepted"
)

local message
messages.show = function(value)
  message = value
end
vim.uv.fs_stat = function()
  return {}
end
assert(not create.run(source, "/tmp/new-app"), "existing destination was accepted")
assert(message:find("Destination already exists", 1, true), "existing destination was not reported")

vim.uv.fs_stat = function()
  return nil
end
assert(
  not create.run("https://example.com/template", "/tmp/new-app"),
  "unsupported template was accepted"
)
assert(message:find("local directory or GitHub", 1, true), "unsupported template was not reported")

local command
vim.fn.mkdir = function() end
vim.fn.filereadable = function()
  return 0
end
vim.schedule = function(callback)
  callback()
end
vim.system = function(value, _, callback)
  command = value
  callback({ code = 0 })
end
assert(create.run(source, "/tmp/new-app"), "local template copy was not started")
assert(command[1] == "cp", "local template used the wrong command")
assert(message:find("Created app", 1, true), "successful creation was not reported")

vim.system = function(_, _, callback)
  callback({ code = 1, stderr = "clone failed\nmore detail" })
end
assert(create.run(source, "/tmp/new-app"), "failed copy was not started")
assert(message == "Could not create app: clone failed", "creation failure was not reported")

local prompted_source
local prompted_destination
local confirmed = 0
create.run = function(template, destination)
  prompted_source = template
  prompted_destination = destination
  return true
end
vim.ui.input = function(_, callback)
  callback("/tmp/prompted-app")
end
create.prompt("/tmp/workspace", function()
  confirmed = confirmed + 1
end)
assert(
  prompted_source == "https://github.com/Appsilon/tapyr-template.git",
  "configured template was not used"
)
assert(prompted_destination == "/tmp/prompted-app", "prompt destination changed")
assert(confirmed == 1, "successful prompt did not close the panel")

vim.ui.input = function(_, callback)
  callback(nil)
end
create.prompt("/tmp/workspace", function()
  confirmed = confirmed + 1
end)
assert(confirmed == 1, "cancelled prompt closed the panel")

vim.fn.delete(source, "rf")
create.run = original_run
messages.show = original_show
vim.fn.filereadable = original_filereadable
vim.fn.mkdir = original_mkdir
vim.schedule = original_schedule
vim.system = original_system
vim.ui.input = original_input
vim.uv.fs_stat = original_fs_stat
