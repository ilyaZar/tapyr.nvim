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

local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local registry = require("tapyr.registry")
local original_find = apps.find
local original_open_in_browser = apps.open_in_browser
local original_show = messages.show
local original_registry_load = registry.load

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
      launch = "shiny run --reload app.py",
      id = listed_id,
      entrypoint = listed_id,
      cwd = listed_root,
      start_time = "1001",
      url = "http://127.0.0.1:8000",
    },
  }
end
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
assert(buffer_mapping(0, "Tapyr: refresh").lhs == "r", "panel refresh mapping is missing")
assert(
  buffer_mapping(0, "Tapyr: restart selected app").lhs == "R",
  "panel restart mapping is missing"
)
assert(buffer_mapping(0, "Tapyr: stop selected app").lhs == "x", "panel stop mapping is missing")
assert(buffer_mapping(0, "Tapyr: open selected app").lhs == "o", "panel open mapping is missing")

local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
assert(first_line:find("[Apps]", 1, true), "Apps view is missing")
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

vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "x", false)
local help_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(help_lines[1]:find("[Help]", 1, true), "Help view did not wrap backward from Apps")
label, highlight = active_tab(0)
assert(label == "[Help]", "Help tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Help tab highlight changed")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
assert(active_tab(0) == "[Apps]", "Apps view did not wrap forward from Help")

local warning
messages.show = function(message)
  warning = message
end
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("x", "x", false)
assert(warning == "Select an app first", "missing app selection was not reported")

local opened_url
apps.open_in_browser = function(url)
  opened_url = url
end
vim.api.nvim_win_set_cursor(0, { 5, 0 })
vim.api.nvim_feedkeys("o", "x", false)
assert(opened_url == "http://127.0.0.1:8000", "selected app URL was not opened")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:find("[Project]", 1, true), "Project view is missing")
assert(lines[5]:find("Ctrl+b", 1, true), "Project view did not show the default run mapping")
assert(
  lines[6]:find("Ctrl+Shift+b", 1, true),
  "Project view did not show the default restart mapping"
)
label, highlight = active_tab(0)
assert(label == "[Project]", "Project tab is not highlighted")
assert(highlight == "DiagnosticWarn", "Project tab highlight changed")

local app_row
for index, line in ipairs(lines) do
  if line:find("/app.py", 1, true) then
    app_row = index
    break
  end
end
assert(app_row, "app.py row is missing")

vim.api.nvim_win_set_cursor(0, { app_row, 0 })
vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
assert(vim.api.nvim_buf_get_name(0) == fixture, "app.py row did not open")

vim.o.columns = 40
vim.o.lines = 12
vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel failed in a narrow editor")
vim.api.nvim_feedkeys("q", "x", false)

require("tapyr").setup({
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
local custom_project_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(
  custom_project_lines[5]:find("<leader>tb", 1, true),
  "Project view did not show the custom run mapping"
)
assert(
  custom_project_lines[7]:find("-", 1, true),
  "Project view did not show the disabled test mapping"
)
vim.api.nvim_feedkeys("q", "x", false)

vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.getcwd(), "README.md")))
assert(not buffer_has_mapping(0, "Tapyr: panel"), "non-Shiny buffer was mapped")

apps.find = original_find
apps.open_in_browser = original_open_in_browser
messages.show = original_show
registry.load = original_registry_load
