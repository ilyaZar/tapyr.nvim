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
vim.cmd.edit(vim.fn.fnameescape(fixture))

local app_buf = vim.api.nvim_get_current_buf()
assert(buffer_has_mapping(app_buf, "Tapyr: panel"), "Shiny buffer mapping is missing")
assert(buffer_mapping(app_buf, "Tapyr: run app").lhs == "<C-B>", "default run mapping changed")
assert(buffer_mapping(app_buf, "Tapyr: restart app").lhs == "<C-S-B>", "default restart mapping changed")

vim.cmd.Tapyr()
assert(vim.bo.filetype == "tapyr", "panel filetype is missing")
assert(buffer_mapping(0, "Tapyr: refresh").lhs == "r", "panel refresh mapping is missing")
assert(buffer_mapping(0, "Tapyr: restart selected app").lhs == "R", "panel restart mapping is missing")
assert(buffer_mapping(0, "Tapyr: stop selected app").lhs == "x", "panel stop mapping is missing")
assert(buffer_mapping(0, "Tapyr: open selected app").lhs == "o", "panel open mapping is missing")

local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
assert(first_line:find("[Apps]", 1, true), "Apps view is missing")
local label, highlight = active_tab(0)
assert(label == "[Apps]", "Apps tab is not highlighted")
assert(highlight == "DiagnosticWarn", "active tab does not use the colorscheme warning color")

vim.api.nvim_feedkeys(vim.keycode("<Tab>"), "x", false)
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:find("[Project]", 1, true), "Project view is missing")
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
  },
})
local custom_buffer = vim.fs.joinpath(
  vim.fn.getcwd(),
  "tests",
  "fixtures",
  "sample-project",
  "custom.py"
)
vim.cmd.edit(vim.fn.fnameescape(custom_buffer))
assert(buffer_mapping(0, "Tapyr: run app").lhs == "\\tb", "custom run mapping was not used")
assert(buffer_mapping(0, "Tapyr: restart app").lhs == "<C-S-B>", "default restart mapping was not kept")
assert(not buffer_has_mapping(0, "Tapyr: panel"), "disabled panel mapping was added")

vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(vim.fn.getcwd(), "README.md")))
assert(not buffer_has_mapping(0, "Tapyr: panel"), "non-Shiny buffer was mapped")
