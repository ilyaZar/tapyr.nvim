local apps = require("shiny.apps")
local create = require("shiny.rgolem.create")
local helpers = require("tests.helpers")
local registry = require("shiny.registry")

local original_columns = vim.o.columns
local original_lines = vim.o.lines
vim.o.columns = 67
vim.o.lines = 24

local root = vim.fn.tempname()
local shelf = vim.fs.joinpath(root, string.rep("längere-ablage-", 7))
local golem_destination
vim.fn.mkdir(vim.fs.joinpath(shelf, "golex01"), "p")
vim.fn.mkdir(vim.fs.joinpath(shelf, "golex02"), "p")
require("shiny").setup({
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
      description = "golem::create_golem()",
    },
  },
  golex = {
    dir = shelf,
    shelves_path = vim.fs.joinpath(root, "golex.json"),
    open_cmd = { "code" },
  },
})

local original_find = apps.find
local original_create_at = create.at
local original_registry_load = registry.load
local original_restart = apps.restart
apps.find = function()
  return {}, nil
end
registry.load = function()
  return {}, {}
end

local state = require("shiny.panel").open(root, nil, "golex")
local panel_buf = state.buf
local lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
assert(lines[1]:find("[Golex]", 1, true), "native Golex tab did not open")
assert(lines[4] == "Add new Golex app", "Golex creation is not the first section")
assert(lines[6] == "new Golex app name > ", "Golex input prompt changed")
assert(lines[8] == "Golex apps", "Golex app selection section is missing")
assert(lines[10] == "golex01" and lines[11] == "golex02", "Golex entries were not listed")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 6, "Golex input was not selected")

local function footer_text()
  return helpers.rendered_footer(state.win)
end

local function has_highlight(line, start_col, group)
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(panel_buf, -1, 0, -1, { details = true })) do
    if mark[2] == line - 1 and mark[3] == start_col and mark[4].hl_group == group then
      return true
    end
  end
  return false
end

local panel_width = vim.api.nvim_win_get_width(state.win)
local path_label = "path to selected shelf: "
assert(vim.startswith(lines[2], path_label), "Golex shelf path label is unclear")
assert(has_highlight(2, 0, "Statement"), "Golex shelf path label is not light purple")
assert(has_highlight(2, #path_label, "DiagnosticOk"), "Golex shelf path is not green")
assert(
  footer_text():find("[Enter] open w/ external editor", 1, true),
  "Golex footer syntax changed"
)
assert(
  footer_text():find("[N/i] edit Golex app name", 1, true),
  "Golex footer lacks its name editor"
)
assert(not footer_text():find("[n]", 1, true), "removed Golex next action remained visible")
assert(not footer_text():find("[R]", 1, true), "Apps footer action leaked into Golex")
for _, line in ipairs(lines) do
  assert(
    vim.fn.strdisplaywidth(line) <= panel_width,
    "Golex content clipped at the 536-pixel acceptance width"
  )
end
local wrapped
for _, candidate in ipairs(vim.api.nvim_list_wins()) do
  if
    vim.bo[vim.api.nvim_win_get_buf(candidate)].filetype == "shiny-footer"
    and vim.api.nvim_win_get_config(candidate).win == state.win
  then
    wrapped = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(candidate), 0, -1, false)
  end
end
assert(wrapped and #wrapped > 1, "narrow Golex footer did not wrap")
for _, line in ipairs(wrapped) do
  assert(vim.fn.strdisplaywidth(line) <= panel_width, "wrapped Golex footer still clipped")
end

local restarted = false
apps.restart = function()
  restarted = true
end
vim.api.nvim_feedkeys("R", "x", false)
assert(not restarted, "hidden Apps restart remained active in Golex")

vim.api.nvim_feedkeys("j", "x", false)
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 10, "Golex entry navigation changed")
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.bo.filetype == "shiny-dialog", "Golex entry action did not use the shared dialog")
local dialog_footer = {}
for _, part in ipairs(vim.api.nvim_win_get_config(0).footer) do
  dialog_footer[#dialog_footer + 1] = part[1]
end
assert(
  table.concat(dialog_footer) == " [q] cancel ",
  "dialog footer contains more than the cancel action"
)
local dialog_line = vim.api.nvim_get_current_line()
local first = assert(dialog_line:find("%S"))
local last = assert(dialog_line:match(".*()%S"))
local dialog_width = vim.api.nvim_win_get_width(0)
assert(math.abs((first - 1) - (dialog_width - last)) <= 1, "dialog choices are not centered")
local selected_warn
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
  if mark[4].hl_group == "DiagnosticWarn" then
    selected_warn = true
  end
end
assert(selected_warn, "dialog selection is not highlighted in yellow")
for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  assert(keymap.lhs ~= "o" and keymap.lhs ~= "R", "dialog retained a hidden choice shortcut")
end
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "dialog cancel did not restore Golex")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 10, "dialog cancel lost Golex selection")

vim.api.nvim_feedkeys("d", "x", false)
assert(vim.bo.filetype == "shiny-dialog", "Golex delete did not open its confirmation")
local confirm_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local confirm_text = table.concat(confirm_lines, ""):gsub("%s", "")
assert(#confirm_lines > 3, "confirmation did not exercise wrapped content")
local confirm_title = {}
for _, part in ipairs(vim.api.nvim_win_get_config(0).title) do
  confirm_title[#confirm_title + 1] = part[1]
end
assert(table.concat(confirm_title) == " Confirm ", "destructive effect remained in the title")
local confirm_choice_line
for _, line in ipairs(confirm_lines) do
  if line:find("[Delete]", 1, true) then
    confirm_choice_line = line
  end
end
assert(confirm_choice_line, "destructive confirmation did not select Delete by default")
assert(
  confirm_choice_line:find("Delete", 1, true) < confirm_choice_line:find("Cancel", 1, true),
  "Cancel is not to the right of Delete"
)
local confirm_first = assert(confirm_choice_line:find("%S"))
local confirm_last = assert(confirm_choice_line:match(".*()%S"))
assert(
  math.abs((confirm_first - 1) - (vim.api.nvim_win_get_width(0) - confirm_last)) <= 1,
  "destructive choices are not centered"
)
assert(
  confirm_text:find((vim.fs.joinpath(shelf, "golex01") .. "recursively?"):gsub("%s", ""), 1, true),
  "destructive confirmation clipped its complete effect"
)
for _, line in ipairs(confirm_lines) do
  assert(
    vim.fn.strdisplaywidth(line) <= vim.api.nvim_win_get_width(0),
    "confirmation content clipped"
  )
end
local confirm_warn
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
  if mark[4].hl_group == "DiagnosticWarn" then
    confirm_warn = true
  end
end
assert(confirm_warn, "destructive selection is not highlighted in yellow")
for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  assert(keymap.lhs ~= "y" and keymap.lhs ~= "n", "confirmation retained a hidden choice shortcut")
end
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "delete cancel did not restore Golex")

local function mapping(description)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(panel_buf, "n")) do
    if keymap.desc == description then
      return keymap
    end
  end
end

vim.api.nvim_feedkeys("S", "x", false)
lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
local active_label = "currently active shelf: "
local back_hint = "Back to Golex apps: [S]"
assert(vim.startswith(lines[2], active_label), "active shelf label is unclear")
assert(vim.endswith(lines[2], back_hint), "shelf view lacks its return hint")
assert(vim.fn.strdisplaywidth(lines[2]) == panel_width, "shelf return hint is not right aligned")
assert(has_highlight(2, 0, "Statement"), "active shelf label is not light purple")
assert(has_highlight(2, #active_label, "DiagnosticOk"), "active shelf path is not green")
assert(has_highlight(2, #lines[2] - #back_hint, "DiagnosticError"), "shelf return hint is not red")
assert(lines[4] == "Shelf selection", "shelf choices are not the first section")
assert(vim.startswith(lines[6], "* "), "active shelf is not first in the selection section")
assert(lines[8] == "Add new shelf", "new shelf section is missing")
assert(lines[10] == "add new shelf name > ", "shelf manager lacks its renamed input")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 6, "shelf selection is not the default focus")
assert(footer_text():find("[Enter] select", 1, true), "shelf Enter action is unclear")
assert(footer_text():find("[N/i] edit shelf name/path", 1, true), "shelf footer did not adjust")
assert(not footer_text():find("new Golex app", 1, true), "app footer leaked into shelves")
for _, line in ipairs(lines) do
  assert(vim.fn.strdisplaywidth(line) <= panel_width, "reworked shelf view clipped")
end

vim.api.nvim_win_set_width(state.win, 44)
state.golex_api.draw(true)
local compact_lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
assert(vim.endswith(compact_lines[2], "[S] apps"), "narrow shelf view lacks its return hint")
assert(vim.fn.strdisplaywidth(compact_lines[2]) <= 44, "compact shelf status clipped")
vim.api.nvim_win_set_width(state.win, panel_width)
state.golex_api.draw(true)

local function input_mapping(bufnr)
  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "i")) do
    if keymap.desc == "Shiny: submit Golex input" then
      return keymap
    end
  end
end

local original_ui_input = vim.ui.input
local shelf_prompt
vim.ui.input = function(options, callback)
  shelf_prompt = { options = options, callback = callback }
end

local shelf_name = "extra"
mapping("Shiny: create in current view").callback()
local shelf_input = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 10, "new shelf action did not select its input")
vim.api.nvim_buf_set_lines(shelf_input, 0, -1, false, { shelf_name })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = shelf_input })
input_mapping(shelf_input).callback()
local cwd = vim.fs.normalize(vim.uv.cwd()):gsub("[/\\]+$", "")
local path_prefix = cwd .. package.config:sub(1, 1)
local named_shelf = path_prefix .. shelf_name
assert(shelf_prompt.options.prompt == "New shelf path: ", "shelf path popup prompt changed")
assert(shelf_prompt.options.completion == "dir", "shelf path popup lacks directory completion")
assert(shelf_prompt.options.default == named_shelf, "shelf name was not placed below the cwd")
shelf_prompt.callback(named_shelf)
local shelves = require("shiny.rgolem.shelves")
assert(shelves.active() == named_shelf, "shelf name popup did not submit its path")

vim.api.nvim_feedkeys("S", "x", false)
mapping("Shiny: create in current view").callback()
shelf_input = vim.api.nvim_get_current_buf()
local full_path = vim.fs.joinpath(root, "full-path")
vim.api.nvim_buf_set_lines(shelf_input, 0, -1, false, { full_path })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = shelf_input })
input_mapping(shelf_input).callback()
assert(
  shelf_prompt.options.default == cwd .. full_path,
  "typed shelf path was not preserved after the cwd prefix"
)
shelf_prompt.callback(full_path)
assert(shelves.active() == full_path, "edited full shelf path was not selected")
vim.ui.input = original_ui_input

shelves.select(1)
state.golex_api.draw()

vim.api.nvim_feedkeys("j", "x", false)
assert(not mapping("Shiny: create next Golex app"), "removed Golex n mapping remained active")
local edit_mapping = assert(mapping("Shiny: edit Golex input"), "Golex i mapping is missing")
assert(edit_mapping.lhs == "i", "Golex editor does not use the insert-mode key")

local created_name
create.at = function(_, package_name)
  created_name = package_name
  return true
end
mapping("Shiny: create in current view").callback()
local input_buf = vim.api.nvim_get_current_buf()
assert(vim.bo.filetype == "shiny-input", "Golex N did not open its isolated input row")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 6, "Golex N did not highlight its input")
assert(not vim.bo[panel_buf].modifiable, "Golex input made the panel buffer modifiable")
assert(vim.api.nvim_get_current_line() == "golex03", "Golex N did not propose the next name")
lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
assert(lines[6] == "new Golex app name > golex03", "default Golex name was not shown")

vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "broken", "green text" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
assert(
  vim.deep_equal(vim.api.nvim_buf_get_lines(input_buf, 0, -1, false), { "golex03" }),
  "multiline Golex input was not rejected"
)
lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
assert(lines[8] == "Golex apps", "Golex input altered protected panel text")
vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "remember.me" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
state.golex_edit.finish(false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "leaving Golex input did not restore the panel")
assert(
  vim.api.nvim_buf_get_lines(panel_buf, 5, 6, false)[1] == "new Golex app name > remember.me",
  "leaving Golex input lost its edited name"
)

edit_mapping.callback()
input_buf = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_get_current_line() == "remember.me", "Golex i did not resume the edited name")
state.golex_edit.finish(false)
mapping("Shiny: create in current view").callback()
input_buf = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_get_current_line() == "remember.me", "Golex N replaced the edited name")

local notification
local original_notify = vim.notify
vim.notify = function(message, level, options)
  notification = { message = message, level = level, options = options }
end
vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "bad_name" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
vim.api.nvim_win_set_cursor(0, { 1, #"bad_name" })
input_mapping(input_buf).callback()
assert(vim.api.nvim_get_current_buf() == input_buf, "invalid Golex input closed its editor")
assert(state.golex_edit and state.golex_edit.buf == input_buf, "invalid Golex input became inert")
assert(vim.api.nvim_win_get_cursor(0)[2] == #"bad_name", "invalid Golex input moved the cursor")
assert(
  notification and notification.level == vim.log.levels.WARN,
  "invalid name warning is missing"
)
assert(notification.options.timeout == 6000, "invalid name warning does not last six seconds")
assert(
  notification.message:find("ASCII letter first", 1, true),
  "invalid name warning omitted the R package-name rule"
)

vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "my.app" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
input_mapping(input_buf).callback()
assert(created_name == "my.app", "Golex input did not submit its edited package name")
assert(vim.api.nvim_get_current_buf() == panel_buf, "Golex submit did not restore the panel")

mapping("Shiny: create in current view").callback()
input_buf = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "still_bad" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
state.golex_edit.finish(false)
notification = nil
mapping("Shiny: open selected item").callback()
assert(notification and notification.options.timeout == 6000, "normal-mode validation is too short")
assert(vim.api.nvim_get_current_buf() == panel_buf, "normal-mode validation left the panel")
edit_mapping.callback()
input_buf = vim.api.nvim_get_current_buf()
assert(vim.api.nvim_get_current_line() == "still_bad", "Golex i lost the invalid draft")
vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, { "fixed.app" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input_buf })
input_mapping(input_buf).callback()
assert(created_name == "fixed.app", "corrected Golex draft did not submit")
vim.notify = original_notify

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local settings_footer = footer_text()
assert(
  settings_footer:find("[Enter] edit setting", 1, true),
  "Settings footer did not adjust: " .. settings_footer
)
for _, line in ipairs(vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)) do
  assert(vim.fn.strdisplaywidth(line) <= panel_width, "narrow Settings content clipped")
end
assert(not footer_text():find("[d]", 1, true), "destructive Golex action leaked into Settings")
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(footer_text():find("[Enter] open link", 1, true), "Help footer did not adjust")
assert(not footer_text():find("[X]", 1, true), "destructive Apps action leaked into Help")
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(footer_text():find("[N] new app template", 1, true), "Apps footer did not wrap")
mapping("Shiny: create in current view").callback()
assert(vim.bo.filetype == "shiny-dialog", "Apps N did not open the template chooser")
local template_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  template_lines[1]:find("[Tapyr (Appsilon/tapyr-template)]", 1, true),
  "Apps chooser did not default to Tapyr"
)
assert(
  template_lines[2]:find("golem (golem::create_golem())", 1, true),
  "Apps chooser omitted the golem hook"
)
for _, line in ipairs(template_lines) do
  assert(
    vim.fn.strdisplaywidth(line) <= vim.api.nvim_win_get_width(0),
    "Apps template chooser clipped"
  )
end
local tapyr_link
for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true })) do
  if mark[4].url == "https://github.com/Appsilon/tapyr-template" then
    tapyr_link = true
  end
end
assert(tapyr_link, "Apps chooser did not expose the Tapyr repository link")
vim.api.nvim_feedkeys("j", "x", false)
assert(
  vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]:find("[golem (golem::create_golem())]", 1, true),
  "Apps chooser did not move to golem"
)
local original_input = vim.ui.input
vim.ui.input = function(_, callback)
  callback("/tmp/from-menu")
end
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
vim.ui.input = original_input
assert(golem_destination == "/tmp/from-menu", "Apps chooser did not dispatch the golem hook")
assert(
  not vim.api.nvim_buf_is_valid(panel_buf),
  "successful template selection did not close the panel"
)

apps.find = original_find
apps.restart = original_restart
create.at = original_create_at
registry.load = original_registry_load
vim.fn.delete(root, "rf")
vim.o.columns = original_columns
vim.o.lines = original_lines
