local helpers = require("tests.helpers")

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
  local namespace = vim.api.nvim_get_namespaces()["shiny.panel"]
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

local apps = require("shiny.apps")
local messages = require("shiny.messages")
local registry = require("shiny.registry")
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

assert(vim.fn.exists(":Shiny") == 2, "Shiny command is missing")
assert(vim.fn.exists(":Tapyr") == 0, "legacy Tapyr command was registered")
assert(vim.fn.exists(":Rgolex") == 0, "legacy Rgolex command was registered")
assert(vim.fn.exists(":Rgx") == 0, "legacy Rgx command was registered")
assert(vim.fn.exists(":GolemRunDev") == 0, "legacy Golem command was registered")
assert(not pcall(require, "tapyr"), "legacy tapyr module is still available")
assert(vim.g.loaded_tapyr == nil, "legacy Tapyr load guard was set")
assert(
  vim.deep_equal(require("shiny").complete("g", "Shiny g"), { "golex" }),
  "top-level command completion changed"
)
assert(
  vim.deep_equal(require("shiny").complete("", "Shiny golex "), { "next" }),
  "Golex command completion changed"
)
assert(
  vim.deep_equal(require("shiny").complete("d", "Shiny action d"), { "document-reload" }),
  "Golem action completion changed"
)

local fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "sample-project", "app.py")
local fixture_root = vim.fs.dirname(fixture)
local fixture_app = assert(require("shiny.backend").detect(fixture_root))
local settings_fixture = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "shiny-settings.lua")
local golex_root = vim.fn.tempname()
vim.fn.mkdir(golex_root, "p")
local golex_options = {
  dir = golex_root,
  shelves_path = vim.fs.joinpath(golex_root, "shelves.json"),
  open_cmd = { "code" },
}
local listed_root = vim.fs.joinpath(fixture_root, "apps", "nested")
local listed_entrypoint = vim.fs.joinpath(listed_root, "app.py")
local listed_id = "python:" .. listed_entrypoint
registry.load = function()
  return {
    {
      id = listed_id,
      backend = "python",
      name = "nested",
      root = listed_root,
      entrypoint = listed_entrypoint,
      commands = {},
    },
  }, {}
end
local listed_pid
local listed_launch = "shiny run --reload app.py"
apps.find = function()
  return {
    {
      port = 8000,
      pid = listed_pid,
      argv = {
        "/tmp/project/.venv/bin/shiny",
        "run",
        "--reload",
        "--port",
        "8000",
        "app.py",
      },
      launch = listed_launch,
      managed = true,
      id = listed_id,
      backend = "python",
      entrypoint = listed_entrypoint,
      cwd = listed_root,
      start_time = "1001",
      url = "http://127.0.0.1:8000",
    },
  }
end
require("shiny").setup({
  settings_path = settings_fixture,
  golex = golex_options,
})
vim.cmd.edit(vim.fn.fnameescape(fixture))

local app_buf = vim.api.nvim_get_current_buf()
assert(buffer_has_mapping(app_buf, "Shiny: panel"), "Shiny buffer mapping is missing")
assert(buffer_mapping(app_buf, "Shiny: run app").lhs == "<C-B>", "default run mapping changed")
assert(
  buffer_mapping(app_buf, "Shiny: restart app").lhs == "<C-S-B>",
  "default restart mapping changed"
)

vim.cmd.Shiny()
assert(vim.bo.filetype == "shiny", "panel filetype is missing")
local panel_buf = vim.api.nvim_get_current_buf()
assert(
  buffer_mapping(0, "Shiny: create in current view").lhs == "N",
  "panel new app mapping is missing"
)
assert(
  buffer_mapping(0, "Shiny: create next Golex app") == nil,
  "removed Golex next-number mapping remained active"
)
assert(buffer_mapping(0, "Shiny: refresh").lhs == "r", "panel refresh mapping is missing")
assert(
  buffer_mapping(0, "Shiny: restart selected app").lhs == "R",
  "panel restart mapping is missing"
)
assert(buffer_mapping(0, "Shiny: stop selected app").lhs == "X", "panel stop mapping is missing")
assert(
  buffer_mapping(0, "Shiny: open selected app in browser").lhs == "b",
  "panel browser mapping is missing"
)
local footer_text = helpers.rendered_footer()
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
assert(app_lines[3]:find("backend", 1, true), "Apps header did not use backend terminology")
assert(
  app_lines[5]:find("running", 1, true) and app_lines[5]:find("nested", 1, true),
  "Apps view did not show the selected app"
)
assert(
  app_lines[6]:find("shiny run --reload app.py", 1, true),
  "compact Apps view did not show the concise launch command"
)
assert(
  app_lines[7]:find("sample-project/apps/nested", 1, true),
  "Apps view did not preserve the nested project path"
)
local namespace = vim.api.nvim_get_namespaces()["shiny.panel"]
local header_marks = vim.api.nvim_buf_get_extmarks(0, namespace, { 2, 0 }, { 2, -1 }, {
  details = true,
})
assert(header_marks[1][4].hl_group == "Bold", "Apps column headings are not bold")
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "Apps did not select its first row")
local selection_namespace = vim.api.nvim_get_namespaces()["shiny.panel.selection"]
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
local detail_win = vim.api.nvim_get_current_win()
local detail_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(vim.api.nvim_get_current_buf() ~= panel_buf, "Enter did not open app details")
local detail_footer = helpers.rendered_footer(detail_win)
assert(detail_footer:find("[r] refresh", 1, true), "app details omitted refresh")
assert(detail_footer:find("[q] close", 1, true), "app details omitted close")
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
assert(
  table.concat(detail_lines, "\n"):find("pid         %-"),
  "app details did not start without a PID"
)
listed_pid = 101
assert(
  vim.wait(1000, function()
    detail_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    return table.concat(detail_lines, "\n"):find("pid         101", 1, true) ~= nil
  end, 20),
  "app details did not receive the automatically discovered PID"
)
assert(vim.api.nvim_get_current_win() == detail_win, "automatic PID refresh left app details")
listed_pid = 202
listed_launch = "shiny run --reload --port 8000 app.py"
vim.api.nvim_feedkeys("r", "x", false)
assert(vim.api.nvim_get_current_win() == detail_win, "refresh left app details")
detail_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  table.concat(detail_lines, "\n"):find("pid         202", 1, true),
  "app details PID did not refresh"
)
assert(
  table.concat(detail_lines, "\n"):find(listed_launch, 1, true),
  "app details launch command did not refresh"
)
vim.api.nvim_feedkeys("q", "x", false)
assert(vim.api.nvim_get_current_buf() == panel_buf, "closing details did not return to Apps")
assert(vim.api.nvim_win_get_cursor(0)[1] == 5, "closing details lost the selected app")

vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "x", false)
local help_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(help_lines[1]:find("[Help]", 1, true), "Help view did not wrap backward from Apps")
local keys_line = assert(find_exact_line(help_lines, "Keys"), "Help view omitted Keys")
local apps_line = assert(find_exact_line(help_lines, "Apps"), "Help view omitted Apps")
local about_line = assert(find_exact_line(help_lines, "About"), "Help view omitted About")
assert(about_line < keys_line and keys_line < apps_line, "Help sections are out of order")
assert(
  select(2, find_line(help_lines, "Tab / Shift+Tab")):find("next / previous view", 1, true),
  "Help view omitted view directions"
)
assert(find_line(help_lines, "use the selected item"), "Help omitted Enter")
assert(find_line(help_lines, "stop the selected running app"), "Help omitted guarded stop")
assert(find_line(help_lines, "default browser"), "Help omitted browser behavior")
assert(find_line(help_lines, "configured app template"), "Help omitted template behavior")
assert(find_line(help_lines, "edit the next numbered Golex app name"), "Help omitted Golex new")
assert(find_line(help_lines, "delete the selected app or shelf"), "Help omitted Golex delete")
assert(find_line(help_lines, "running     1"), "Help running count does not match Apps")
assert(find_line(help_lines, "stopped     0"), "Help stopped count does not match Apps")
assert(find_line(help_lines, "Python      1"), "Help Python count does not match Apps")
assert(find_line(help_lines, "Golem       0"), "Help Golem count does not match Apps")
local workspace = vim.fn.fnamemodify(fixture_root, ":~")
workspace =
  require("shiny.text").shorten(workspace, math.max(vim.api.nvim_win_get_width(0) - 14, 10))
assert(find_line(help_lines, workspace), "Help omitted the active workspace")
assert(not find_line(help_lines, "tracked:"), "Help retained the tracked count")
label, highlight = active_tab(0)
assert(label == "[Help]", "Help tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Help tab highlight changed")

local repository_line = assert(find_line(help_lines, "Project repository"))
local issue_line = assert(find_line(help_lines, "File an issue"))
local pull_line = assert(find_line(help_lines, "Pull requests"))
local license_line = assert(find_line(help_lines, "MIT License"))
assert(vim.api.nvim_win_get_cursor(0)[1] == repository_line, "Help did not select its first link")
vim.api.nvim_win_set_cursor(0, { keys_line, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf })
assert(
  vim.tbl_contains(
    { repository_line, issue_line, pull_line, license_line },
    vim.api.nvim_win_get_cursor(0)[1]
  ),
  "direct movement escaped Help links"
)

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
vim.api.nvim_win_set_cursor(0, { repository_line, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf })
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
local golex_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(golex_lines[1]:find("[Golex]", 1, true), "Golex view is missing")
assert(golex_lines[4] == "new Golex app > ", "Golex editable row changed")
assert(vim.api.nvim_win_get_cursor(0)[1] == 4, "Golex input row was not selected")
footer_text = helpers.rendered_footer()
assert(footer_text:find("[Enter] create/open", 1, true), "Golex Enter action is missing")
assert(footer_text:find("[N] new Golex app", 1, true), "Golex new-app action is missing")
assert(not footer_text:find("[n]", 1, true), "removed Golex next action remained in the footer")
assert(not footer_text:find("[R] (re)start", 1, true), "Apps actions leaked into Golex")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:find("[Settings]", 1, true), "Settings view is missing")
assert(lines[3] == "Mappings", "Settings omitted the mappings section")
assert(lines[6]:find("Ctrl+b", 1, true), "Settings did not show the default run mapping")
assert(lines[7]:find("Ctrl+Shift+b", 1, true), "Settings did not show the default restart mapping")
label, highlight = active_tab(0)
assert(label == "[Settings]", "Settings tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Settings tab highlight changed")
assert(lines[10]:find("document Golem", 1, true), "Settings omitted document and reload")
assert(lines[11]:find("run Golem dev", 1, true), "Settings omitted the Golem dev script")
assert(lines[13] == "Creation templates", "Settings omitted the creation-template section")
assert(
  lines[16]:find("Tapyr", 1, true) and lines[16]:find("repository", 1, true),
  "Settings omitted the Tapyr repository template"
)
assert(
  lines[17]:find("golem", 1, true) and lines[17]:find("golem::create_golem()", 1, true),
  "Settings omitted the golem creation hook"
)
footer_text = helpers.rendered_footer()
assert(footer_text:find("[Enter] edit setting", 1, true), "Settings footer described only mappings")
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

require("shiny").open(fixture_app)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
vim.api.nvim_feedkeys("G", "x", false)
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(
  vim.api.nvim_get_current_line():find("creation_templates =", 1, true),
  "Settings did not move to the creation_templates setting"
)

local original_columns = vim.o.columns
local original_lines = vim.o.lines
vim.o.columns = 67
vim.o.lines = 24
vim.cmd.Shiny()
assert(vim.bo.filetype == "shiny", "panel failed in a narrow editor")
local narrow_win = vim.api.nvim_get_current_win()
local narrow_width = vim.api.nvim_win_get_width(narrow_win)
local narrow_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
for _, line in ipairs(narrow_lines) do
  assert(
    vim.fn.strdisplaywidth(line) <= narrow_width,
    "Apps content clipped at the 536-pixel acceptance width"
  )
end
local narrow_footer = helpers.rendered_footer(narrow_win)
assert(
  narrow_footer:find("[N] new app template", 1, true),
  "narrow Apps footer dropped the new-app action"
)
local wrapped_footer
for _, candidate in ipairs(vim.api.nvim_list_wins()) do
  if
    vim.bo[vim.api.nvim_win_get_buf(candidate)].filetype == "shiny-footer"
    and vim.api.nvim_win_get_config(candidate).win == narrow_win
  then
    wrapped_footer = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(candidate), 0, -1, false)
  end
end
assert(wrapped_footer and #wrapped_footer > 1, "narrow Apps footer did not wrap")
for _, line in ipairs(wrapped_footer) do
  assert(
    vim.fn.strdisplaywidth(line) <= narrow_width,
    "wrapped footer still clipped at the acceptance width"
  )
end
vim.api.nvim_feedkeys("q", "x", false)
vim.o.columns = original_columns
vim.o.lines = original_lines

require("shiny").setup({
  settings_path = settings_fixture,
  golex = golex_options,
  mappings = {
    run = "<leader>tb",
    panel = false,
    test = false,
  },
})
local custom_buffer =
  vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "sample-project", "custom.py")
vim.cmd.edit(vim.fn.fnameescape(custom_buffer))
assert(buffer_mapping(0, "Shiny: run app").lhs == "\\tb", "custom run mapping was not used")
assert(
  buffer_mapping(0, "Shiny: restart app").lhs == "<C-S-B>",
  "default restart mapping was not kept"
)
assert(not buffer_has_mapping(0, "Shiny: panel"), "disabled panel mapping was added")
assert(not buffer_has_mapping(0, "Shiny: test"), "disabled test mapping was added")

require("shiny").open(fixture_app)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local custom_settings_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  custom_settings_lines[6]:find("<leader>tb", 1, true),
  "Settings did not show the custom run mapping"
)
assert(
  custom_settings_lines[8]:find("-", 1, true),
  "Settings did not show the disabled test mapping"
)
vim.api.nvim_feedkeys("q", "x", false)

local warning
messages.show = function(message)
  warning = message
end
local missing_settings = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures", "missing.lua")
require("shiny").setup({
  settings_path = missing_settings,
  golex = golex_options,
})
require("shiny").open(fixture_app)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local missing_panel = vim.api.nvim_get_current_buf()
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.api.nvim_get_current_buf() == missing_panel, "missing Settings file closed the panel")
assert(warning == "Shiny settings file is not readable", "missing Settings file was not reported")
assert(vim.fn.filereadable(missing_settings) == 0, "missing Settings file was created")
vim.api.nvim_feedkeys("q", "x", false)

vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.getcwd(), "README.md")))
assert(not buffer_has_mapping(0, "Shiny: panel"), "non-Shiny buffer was mapped")

apps.find = original_find
apps.open_in_browser = original_open_in_browser
messages.show = original_show
registry.load = original_registry_load
vim.ui.open = original_ui_open
vim.fn.delete(golex_root, "rf")
