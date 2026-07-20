local apps = require("shiny.apps")
local helpers = require("tests.helpers")
local registry = require("shiny.registry")

local root = vim.fn.tempname()
local shelf = vim.fs.joinpath(root, "shelf")
vim.fn.mkdir(vim.fs.joinpath(shelf, "golex01"), "p")
vim.fn.mkdir(vim.fs.joinpath(shelf, "golex02"), "p")
require("shiny").setup({
  golex = {
    dir = shelf,
    shelves_path = vim.fs.joinpath(root, "golex.json"),
    open_cmd = { "code" },
  },
})

local original_find = apps.find
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
assert(lines[4] == "new Golex app > ", "Golex input is not the first data row")
assert(lines[8] == "golex01" and lines[9] == "golex02", "Golex entries were not listed")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 4, "Golex input was not selected")

local function footer_text()
  return helpers.rendered_footer(state.win)
end

assert(footer_text():find("[Enter] create/open", 1, true), "Golex footer syntax changed")
assert(footer_text():find("[N] new Golex app", 1, true), "Golex footer lacks its new action")
assert(not footer_text():find("[R]", 1, true), "Apps footer action leaked into Golex")
local panel_width = vim.api.nvim_win_get_width(state.win)
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
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 8, "Golex entry navigation changed")
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.bo.filetype == "shiny-dialog", "Golex entry action did not use the shared dialog")
local dialog_footer = {}
for _, part in ipairs(vim.api.nvim_win_get_config(0).footer) do
  dialog_footer[#dialog_footer + 1] = part[1]
end
assert(
  table.concat(dialog_footer):find("[Enter] choose", 1, true),
  "dialog footer did not use shared bracket syntax"
)
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "dialog cancel did not restore Golex")
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 8, "dialog cancel lost Golex selection")

vim.api.nvim_feedkeys("S", "x", false)
lines = vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false)
assert(lines[4] == "add shelf > ", "shelf manager lacks its editable row")
assert(footer_text():find("[N] new shelf", 1, true), "shelf footer did not adjust")
assert(not footer_text():find("new Golex app", 1, true), "app footer leaked into shelves")
vim.api.nvim_feedkeys("S", "x", false)

vim.api.nvim_feedkeys("j", "x", false)
vim.api.nvim_feedkeys("N", "x", false)
assert(vim.api.nvim_win_get_cursor(state.win)[1] == 4, "Golex N did not select its input")
vim.cmd.stopinsert()

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local settings_footer = footer_text()
assert(
  settings_footer:find("[Enter] edit mapping", 1, true),
  "Settings footer did not adjust: " .. settings_footer
)
assert(not footer_text():find("[d]", 1, true), "destructive Golex action leaked into Settings")
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(footer_text():find("[Enter] open link", 1, true), "Help footer did not adjust")
assert(not footer_text():find("[X]", 1, true), "destructive Apps action leaked into Help")
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(footer_text():find("[N] new app template", 1, true), "Apps footer did not wrap")
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(footer_text():find("[N] new Golex app", 1, true), "wrapped footer did not update")
vim.api.nvim_feedkeys("q", "x", false)
assert(not vim.api.nvim_buf_is_valid(panel_buf), "panel did not close")

apps.find = original_find
apps.restart = original_restart
registry.load = original_registry_load
vim.fn.delete(root, "rf")
