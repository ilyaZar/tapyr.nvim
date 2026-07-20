local function buffer_mapping(bufnr, desc)
  for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    if mapping.desc == desc then
      return mapping
    end
  end
end

local function buffer_has_mapping(bufnr, desc)
  return buffer_mapping(bufnr, desc) ~= nil
end

local function active_tab(bufnr)
  local namespace = vim.api.nvim_get_namespaces()["tapyr.panel"]
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {
    details = true,
  })
  local mark = marks[1]
  local line = vim.api.nvim_buf_get_lines(bufnr, mark[2], mark[2] + 1, false)[1]
  return line:sub(mark[3] + 1, mark[4].end_col), mark[4].hl_group
end

local function find_line(lines, pattern)
  for line_number, line in ipairs(lines) do
    if line:find(pattern, 1, true) then
      return line_number, line
    end
  end
end

local function find_exact_line(lines, expected)
  for line_number, line in ipairs(lines) do
    if line == expected then
      return line_number
    end
  end
end

local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local registry = require("tapyr.registry")
local original_find = apps.find
local original_open_in_browser = apps.open_in_browser
local original_show = messages.show
local original_registry_load = registry.load
local original_ui_open = vim.ui.open

assert(
  apps.is_public_listener({ "uv", "run", "shiny", "run", "app.py", "--reload" }, 8000),
  "default reload app port was hidden"
)
assert(
  not apps.is_public_listener({ "uv", "run", "shiny", "run", "app.py", "--reload" }, 37474),
  "default reload redirect port was shown"
)
assert(
  apps.is_public_listener(
    { "python", "/tmp/venv/bin/shiny", "run", "app.py", "--reload", "--port", "8123" },
    8123
  ),
  "explicit reload app port was hidden"
)
assert(
  not apps.is_public_listener(
    { "python", "/tmp/venv/bin/shiny", "run", "app.py", "--reload", "--port=8123" },
    37474
  ),
  "explicit reload redirect port was shown"
)
assert(
  apps.is_public_listener({ "uv", "run", "shiny", "run", "app.py" }, 8123),
  "non-reload listener was hidden"
)
assert(
  apps.is_public_listener({ "uv", "run", "shiny", "run", "app.py", "-r", "-p", "0" }, 49152),
  "random reload app port was hidden"
)
assert(
  apps.is_public_listener({ "uv", "run", "shiny", "run", "app.py", "-r", "-p0" }, 37474),
  "random reload listener was hidden without enough information"
)
assert(not apps.is_public_listener({
  "uv",
  "run",
  "shiny",
  "run",
  "app.py",
  "-r",
  "--port=0",
  "--autoreload-port=37474",
}, 37474), "known autoreload port was shown")

assert(vim.fn.exists(":Tapyr") == 2, "Tapyr command is missing")

local fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "sample-project", "app.py")
local fixture_root = vim.fs.dirname(fixture)
local fixture_app = require("tapyr.project").new(fixture_root)
local settings_fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "tapyr-settings.lua")
local listed_root = vim.fs.joinpath(fixture_root, "apps", "nested")
local listed_id = vim.fs.joinpath(listed_root, "app.py")
registry.load = function()
  return {
    {
      id = listed_id,
      name = "nested",
      root = listed_root,
      entrypoint = listed_id,
    },
  }, {}
end
apps.find = function()
  return {
    {
      port = 8000,
      pid = 101,
      argv = {
        "/tmp/project/.venv/bin/shiny",
        "run",
        "--reload",
        "--port",
        "8000",
        "app.py",
      },
      launch = "shiny run --reload app.py",
      id = listed_id,
      entrypoint = listed_id,
      cwd = listed_root,
      start_time = "1001",
      url = "http://127.0.0.1:8000",
    },
  }
end
require("tapyr").setup({
  settings_path = settings_fixture,
})
vim.cmd.edit(vim.fn.fnameescape(fixture))

local app_buf = vim.api.nvim_get_current_buf()
assert(buffer_has_mapping(app_buf, "Tapyr: panel"), "Shiny buffer mapping is missing")
assert(buffer_mapping(app_buf, "Tapyr: run app").lhs == "<C-B>", "default run mapping changed")
assert(
  buffer_mapping(app_buf, "Tapyr: restart app").lhs == "<C-S-B>",
  "default restart mapping changed"
)

vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel filetype is missing")
local panel_buf = vim.api.nvim_get_current_buf()
assert(buffer_mapping(0, "Tapyr: create app").lhs == "N", "panel new app mapping is missing")
assert(vim.fn.maparg("n", "n", false, true).buffer ~= 1, "lowercase n creates an app")
assert(buffer_mapping(0, "Tapyr: refresh").lhs == "r", "panel refresh mapping is missing")
assert(
  buffer_mapping(0, "Tapyr: restart selected app").lhs == "R",
  "panel restart mapping is missing"
)
assert(buffer_mapping(0, "Tapyr: stop selected app").lhs == "X", "panel stop mapping is missing")
assert(
  buffer_mapping(0, "Tapyr: open selected app in browser").lhs == "b",
  "panel browser mapping is missing"
)
local footer_parts = {}
for _, part in ipairs(vim.api.nvim_win_get_config(0).footer) do
  footer_parts[#footer_parts + 1] = part[1]
end
local footer_text = table.concat(footer_parts)
assert(footer_text:find("[Enter] app info", 1, true), "footer app info action is missing")
assert(footer_text:find("[R] (re)start", 1, true), "footer restart action is missing")
assert(footer_text:find("[X] stop", 1, true), "footer stop action is missing")
assert(footer_text:find("[b] browser", 1, true), "footer browser action is missing")
assert(footer_text:find("[N] new app template", 1, true), "footer template action is missing")
assert(not footer_text:find("Tab:views", 1, true), "view hint remained in the footer")

local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
assert(first_line:find("[Apps]", 1, true), "Apps view is missing")
assert(first_line:find("Tab:views", 1, true), "view hint is missing beside the tabs")
local label, highlight = active_tab(0)
assert(label == "[Apps]", "Apps tab is not highlighted")
assert(highlight == "DiagnosticWarn", "active tab does not use the colorscheme warning color")
local app_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  app_lines[5]:find("running", 1, true)
    and app_lines[5]:find("nested", 1, true)
    and app_lines[5]:find("shiny run --reload app.py", 1, true),
  "Apps view did not show the concise launch command"
)
assert(
  app_lines[5]:find("sample-project/apps/nested", 1, true),
  "Apps view did not preserve the nested project path"
)
local namespace = vim.api.nvim_get_namespaces()["tapyr.panel"]
local header_marks = vim.api.nvim_buf_get_extmarks(0, namespace, { 2, 0 }, { 2, -1 }, {
  details = true,
})
assert(header_marks[1][4].hl_group == "Bold", "Apps column headings are not bold")
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "Apps did not select its first row")
local selection_namespace = vim.api.nvim_get_namespaces()["tapyr.panel.selection"]
local selection_marks = vim.api.nvim_buf_get_extmarks(0, selection_namespace, 0, -1, {
  details = true,
})
assert(selection_marks[1][4].line_hl_group == "Visual", "selected row highlight changed")

vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf })
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "direct movement escaped Apps rows")

vim.api.nvim_feedkeys("G", "x", false)
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "G escaped Apps rows")

vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
local detail_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(vim.api.nvim_get_current_buf() ~= panel_buf, "Enter did not open app details")
assert(
  table.concat(detail_lines, "\n"):find("shiny run --reload app.py", 1, true),
  "app details omitted the launch command"
)
assert(
  not table.concat(detail_lines, "\n"):find("/tmp/project/.venv", 1, true),
  "app details exposed internal launch paths"
)
assert(
  table.concat(detail_lines, "\n"):find(listed_root, 1, true),
  "app details omitted the project"
)
assert(
  table.concat(detail_lines, "\n"):find("entrypoint  app.py", 1, true),
  "app details did not make the entrypoint relative"
)
assert(table.concat(detail_lines, "\n"):find("tracked", 1, true), "app details omitted provenance")
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "closing details did not return to Apps")
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "closing details lost the selected app")

vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "x", false)
local help_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(help_lines[1]:find("[Help]", 1, true), "Help view did not wrap backward from Apps")
local keys_line = assert(find_exact_line(help_lines, "Keys"), "Help view omitted Keys")
local apps_line = assert(find_exact_line(help_lines, "Apps"), "Help view omitted Apps")
local about_line = assert(find_exact_line(help_lines, "About"), "Help view omitted About")
assert(keys_line < apps_line and apps_line < about_line, "Help sections are out of order")
assert(
  select(2, find_line(help_lines, "Tab / Shift+Tab")):find("next / previous view", 1, true),
  "Help view omitted view directions"
)
assert(find_line(help_lines, "app info or edit selected Settings mapping"), "Help omitted Enter")
assert(find_line(help_lines, "stop the selected running app"), "Help omitted guarded stop")
assert(find_line(help_lines, "default browser"), "Help omitted browser behavior")
assert(find_line(help_lines, "configured template"), "Help omitted template behavior")
assert(find_line(help_lines, "running     1"), "Help running count does not match Apps")
assert(find_line(help_lines, "stopped     0"), "Help stopped count does not match Apps")
local workspace = vim.fn.fnamemodify(fixture_root, ":~")
workspace =
  require("tapyr.text").shorten(workspace, math.max(vim.api.nvim_win_get_width(0) - 14, 10))
assert(find_line(help_lines, workspace), "Help omitted the active workspace")
assert(not find_line(help_lines, "tracked:"), "Help retained the tracked count")
label, highlight = active_tab(0)
assert(label == "[Help]", "Help tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Help tab highlight changed")

local repository_line = assert(find_line(help_lines, "Tapyr repository"))
local issue_line = assert(find_line(help_lines, "File an issue"))
assert(vim.api.nvim_win_get_cursor(0)[1] == repository_line, "Help did not select its first link")
vim.api.nvim_win_set_cursor(0, { keys_line, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf })
assert(vim.api.nvim_win_get_cursor(0)[1] == repository_line, "direct movement escaped Help links")

if vim.fn.has("nvim-0.11") == 1 then
  local link_marks = vim.api.nvim_buf_get_extmarks(0, namespace, { about_line, 0 }, -1, {
    details = true,
  })
  local urls = {}
  for _, mark in ipairs(link_marks) do
    if mark[4].url then
      urls[mark[4].url] = true
    end
  end
  assert(urls["https://github.com/ilyaZar/tapyr.nvim"], "repository URL extmark is missing")
  assert(urls["https://github.com/ilyaZar/tapyr.nvim/issues"], "issue URL extmark is missing")
  assert(urls["https://github.com/ilyaZar/tapyr.nvim/pulls"], "pull request URL extmark is missing")
  assert(
    urls["https://github.com/ilyaZar/tapyr.nvim/blob/main/LICENSE"],
    "license URL extmark is missing"
  )
end

local opened_help_url
vim.ui.open = function(url)
  opened_help_url = url
end
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(
  opened_help_url == "https://github.com/ilyaZar/tapyr.nvim",
  "Enter did not open the repository"
)
assert(vim.api.nvim_get_current_buf() == panel_buf, "opening a Help link closed the panel")
vim.api.nvim_feedkeys("j", "x", false)
assert(vim.api.nvim_win_get_cursor(0)[1] == issue_line, "Help did not select the next link")
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(
  opened_help_url == "https://github.com/ilyaZar/tapyr.nvim/issues",
  "Enter did not open the issue page"
)

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(active_tab(0) == "[Apps]", "Apps view did not wrap forward from Help")

local opened_url
apps.open_in_browser = function(url)
  opened_url = url
end
vim.api.nvim_feedkeys("b", "x", false)
assert(opened_url == "http://127.0.0.1:8000", "selected app URL was not opened")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:find("[Settings]", 1, true), "Settings view is missing")
assert(lines[5]:find("Ctrl+b", 1, true), "Settings did not show the default run mapping")
assert(lines[6]:find("Ctrl+Shift+b", 1, true), "Settings did not show the default restart mapping")
label, highlight = active_tab(0)
assert(label == "[Settings]", "Settings tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Settings tab highlight changed")
assert(#lines == 8, "Settings contains entries beyond the four supported actions")
assert(
  not table.concat(lines, "\n"):find("pyproject.toml", 1, true),
  "Settings retained pyproject.toml"
)

vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.api.nvim_buf_get_name(0) == settings_fixture, "Settings did not open its Lua file")
assert(
  vim.api.nvim_get_current_line():find("run = ", 1, true),
  "Settings did not move to the run mapping"
)

vim.o.columns = 40
vim.o.lines = 12
vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel failed in a narrow editor")
vim.api.nvim_feedkeys("q", "x", false)

require("tapyr").setup({
  settings_path = settings_fixture,
  mappings = {
    run = "<leader>tb",
    panel = false,
    test = false,
  },
})
local custom_buffer =
  vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "sample-project", "custom.py")
vim.cmd.edit(vim.fn.fnameescape(custom_buffer))
assert(buffer_mapping(0, "Tapyr: run app").lhs == "\\tb", "custom run mapping was not used")
assert(
  buffer_mapping(0, "Tapyr: restart app").lhs == "<C-S-B>",
  "default restart mapping was not kept"
)
assert(not buffer_has_mapping(0, "Tapyr: panel"), "disabled panel mapping was added")
assert(not buffer_has_mapping(0, "Tapyr: test"), "disabled test mapping was added")

require("tapyr").open(fixture_app)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local custom_settings_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  custom_settings_lines[5]:find("<leader>tb", 1, true),
  "Settings did not show the custom run mapping"
)
assert(
  custom_settings_lines[7]:find("-", 1, true),
  "Settings did not show the disabled test mapping"
)
vim.api.nvim_feedkeys("q", "x", false)

local warning
messages.show = function(message)
  warning = message
end
local missing_settings = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "missing.lua")
require("tapyr").setup({
  settings_path = missing_settings,
})
require("tapyr").open(fixture_app)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local missing_panel = vim.api.nvim_get_current_buf()
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.api.nvim_get_current_buf() == missing_panel, "missing Settings file closed the panel")
assert(warning == "Tapyr settings file is not readable", "missing Settings file was not reported")
assert(vim.fn.filereadable(missing_settings) == 0, "missing Settings file was created")
vim.api.nvim_feedkeys("q", "x", false)

vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.getcwd(), "README.md")))
assert(not buffer_has_mapping(0, "Tapyr: panel"), "non-Shiny buffer was mapped")

apps.find = original_find
apps.open_in_browser = original_open_in_browser
messages.show = original_show
registry.load = original_registry_load
vim.ui.open = original_ui_open
