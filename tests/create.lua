local create = require("shiny.create")
local dialog = require("shiny.dialog")
local messages = require("shiny.messages")
local shiny = require("shiny")

local original_config = vim.deepcopy(shiny.config)
local original_menu = dialog.menu
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
assert(
  create.describe({ source = source, create = function() end }) == "invalid",
  "ambiguous template provider was accepted"
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
local prompt_options
local menu_choices
local confirmed = 0
local golem_available = false
local golem_destination
shiny.setup({
  creation_templates = {
    {
      name = "Tapyr",
      source = "https://github.com/Appsilon/tapyr-template.git",
    },
    {
      name = "golem",
      create = function(destination)
        golem_destination = destination
        return true
      end,
      available = function()
        return golem_available
      end,
      description = "golem::create_golem()",
    },
  },
})
create.run = function(template, destination)
  prompted_source = template
  prompted_destination = destination
  return true
end
dialog.menu = function(parent, title, choices, callback)
  assert(parent == 42, "template menu lost its parent window")
  assert(title == "New Shiny app", "template menu title changed")
  menu_choices = choices
  callback(choices[1].value)
end
vim.ui.input = function(options, callback)
  prompt_options = options
  callback("/tmp/prompted-app")
end
create.prompt(42, function()
  confirmed = confirmed + 1
end)
assert(#menu_choices == 1, "unavailable golem hook was offered")
assert(menu_choices[1].label == "Tapyr (Appsilon/tapyr-template)", "Tapyr choice changed")
assert(
  menu_choices[1].url == "https://github.com/Appsilon/tapyr-template",
  "Tapyr repository link changed"
)
assert(
  prompted_source == "https://github.com/Appsilon/tapyr-template.git",
  "configured template was not used"
)
assert(prompted_destination == "/tmp/prompted-app", "prompt destination changed")
assert(
  prompt_options.default == vim.uv.cwd() .. "/",
  "prompt did not default to the working directory"
)
assert(confirmed == 1, "successful prompt did not close the panel")

golem_available = true
dialog.menu = function(_, _, choices, callback)
  menu_choices = choices
  callback(choices[2].value)
end
vim.ui.input = function(_, callback)
  callback("/tmp/my.golem")
end
create.prompt(42, function()
  confirmed = confirmed + 1
end)
assert(#menu_choices == 2, "installed golem hook was not offered")
assert(menu_choices[2].label == "golem (golem::create_golem())", "golem choice changed")
assert(golem_destination == "/tmp/my.golem", "golem hook lost the selected destination")
assert(confirmed == 2, "successful golem prompt did not close the panel")

vim.ui.input = function(_, callback)
  callback(nil)
end
create.prompt(42, function()
  confirmed = confirmed + 1
end)
assert(confirmed == 2, "cancelled prompt closed the panel")

create.run = original_run
shiny.setup({
  creation_templates = {
    {
      name = "script",
      command = { "create-app", "--output", "{destination}" },
    },
  },
})
assert(#shiny.config.creation_templates == 1, "custom template list retained a default entry")
dialog.menu = function(_, _, choices, callback)
  callback(choices[1].value)
end
vim.ui.input = function(_, callback)
  callback("/tmp/100%app")
end
vim.system = function(value, _, callback)
  command = value
  callback({ code = 0 })
end
create.prompt(42)
assert(
  vim.deep_equal(command, { "create-app", "--output", "/tmp/100%app" }),
  "custom command did not receive the destination as one argv value"
)

vim.fn.delete(source, "rf")
shiny.setup(original_config)
dialog.menu = original_menu
messages.show = original_show
vim.fn.filereadable = original_filereadable
vim.fn.mkdir = original_mkdir
vim.schedule = original_schedule
vim.system = original_system
vim.ui.input = original_input
vim.uv.fs_stat = original_fs_stat
