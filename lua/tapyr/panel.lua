local panel = {}

local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local tasks = require("tapyr.tasks")
local text = require("tapyr.text")

local highlight_namespace = vim.api.nvim_create_namespace("tapyr.panel")

local views = {
  { key = "apps", label = "Apps" },
  { key = "project", label = "Project" },
  { key = "help", label = "Help" },
}

local project_items = {
  {
    kind = "task",
    name = "run app",
    mapping = "run",
    command = tasks.describe("run"),
  },
  {
    kind = "task",
    name = "restart app",
    mapping = "restart",
    command = tasks.describe("run"),
  },
  {
    kind = "task",
    name = "test app",
    mapping = "test",
    command = tasks.describe("test"),
  },
  {
    kind = "path",
    name = "app",
    path = "app.py",
  },
  {
    kind = "path",
    name = "project",
    path = "pyproject.toml",
  },
}

local function mapping_label(mapping)
  if not mapping then
    return "-"
  end

  local key = mapping:match("^<C%-S%-(.)>$")
  if key then
    return "Ctrl+Shift+" .. key
  end

  key = mapping:match("^<C%-(.)>$")
  if key then
    return "Ctrl+" .. key
  end

  return mapping
end

local function view_bar(active)
  local parts = {}
  for index, view in ipairs(views) do
    local label = view.label
    if index == active then
      label = "[" .. label .. "]"
    else
      label = " " .. label .. " "
    end
    parts[#parts + 1] = label
  end
  return table.concat(parts, "  ")
end

local function footer()
  return {
    { " " },
    { "Tab", "DiagnosticOk" },
    { ":views  " },
    { "[r]", "DiagnosticOk" },
    { " refresh  " },
    { "[R]", "DiagnosticOk" },
    { " restart  " },
    { "[x]", "DiagnosticOk" },
    { " stop  " },
    { "[o]", "DiagnosticOk" },
    { " open  " },
    { "[q]", "DiagnosticOk" },
    { " close " },
  }
end

local function title(root)
  local project = vim.fs.basename(root or vim.uv.cwd())
  return {
    { " Tapyr ", "FloatTitle" },
    { text.shorten(project, 52), "Comment" },
    { " ", "FloatTitle" },
  }
end

local function project_label(project, root)
  if not project then
    return "-"
  end
  if project == root then
    return vim.fs.basename(root)
  end
  if vim.startswith(project, root .. "/") then
    return vim.fs.basename(root) .. project:sub(#root + 1)
  end
  return vim.fs.basename(project)
end

local function draw_apps(state)
  local found_apps, note = apps.find()
  state.apps = found_apps

  local lines = {
    view_bar(state.view),
    "",
    text.column("host", 16)
      .. " "
      .. text.column("port", 6)
      .. " "
      .. text.column("pid", 8)
      .. " "
      .. text.column("launch", 32)
      .. " project",
    string.rep("-", 86),
  }

  if vim.tbl_isempty(found_apps) then
    lines[#lines + 1] = "No local Shiny apps found"
    if note then
      lines[#lines + 1] = note
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Press Ctrl+b in a Shiny project to start one"
    return lines
  end

  for _, app in ipairs(found_apps) do
    local line_number = #lines + 1
    state.items_by_line[line_number] = {
      kind = "app",
      app = app,
    }
    lines[#lines + 1] = text.column(app.host, 16)
      .. " "
      .. text.column(app.port, 6)
      .. " "
      .. text.column(app.pid or "-", 8)
      .. " "
      .. text.column(app.launch or "-", 32)
      .. " "
      .. text.shorten(project_label(app.project, state.root), 38)
    if not state.first_item then
      state.first_item = line_number
    end
  end

  return lines
end

local function draw_project(state)
  local mappings = require("tapyr").config.mappings
  local lines = {
    view_bar(state.view),
    "",
    text.column("entry", 18) .. " " .. text.column("key", 14) .. " detail",
    string.rep("-", 74),
  }

  for _, item in ipairs(project_items) do
    if item.kind == "task" then
      lines[#lines + 1] = text.column(item.name, 18)
        .. " "
        .. text.column(mapping_label(mappings[item.mapping]), 14)
        .. " "
        .. item.command
    elseif item.kind == "path" then
      local line_number = #lines + 1
      local path = vim.fs.joinpath(state.root, item.path)
      state.items_by_line[line_number] = {
        kind = "path",
        path = path,
      }
      lines[#lines + 1] = text.column(item.name, 18)
        .. " "
        .. text.column("Enter", 14)
        .. " "
        .. path
      state.first_item = state.first_item or line_number
    end
  end

  return lines
end

local function draw_help(state)
  local found_apps, note = apps.find()

  local lines = {
    view_bar(state.view),
    "",
    "keys",
    "  Tab       change view",
    "  r         refresh apps",
    "  R/x/o     restart, stop, or open the selected app",
    "  Enter     open a file from Project",
    "  q/Esc     close",
    "",
    "project",
    "  apps found: " .. #found_apps,
    "  project: " .. state.root,
    "",
    "notes",
    "  app details come from /proc",
    "  restart uses the default command for this project",
  }

  if note then
    lines[#lines + 1] = "  " .. note
  end

  return lines
end

local function current_item(state)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return nil
  end

  local line_number = vim.api.nvim_win_get_cursor(state.win)[1]
  return state.items_by_line and state.items_by_line[line_number] or nil
end

local function selected_app(state)
  local item = current_item(state)
  if not item or not item.app then
    messages.show("Select an app first", vim.log.levels.WARN)
    return nil
  end
  return item.app
end

local function close(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

local function draw(state)
  state.items_by_line = {}
  state.first_item = nil

  local view = views[state.view].key
  local lines
  if view == "apps" then
    lines = draw_apps(state)
  elseif view == "project" then
    lines = draw_project(state)
  else
    lines = draw_help(state)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })

  local active_label = "[" .. views[state.view].label .. "]"
  local start_col, end_col = lines[1]:find(active_label, 1, true)
  vim.api.nvim_buf_clear_namespace(state.buf, highlight_namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 0, start_col - 1, {
    end_col = end_col,
    hl_group = "DiagnosticWarn",
  })
  if view ~= "help" then
    vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 2, 0, {
      end_col = #lines[3],
      hl_group = { "DiagnosticOk", "Bold" },
    })
  end

  if state.first_item then
    pcall(vim.api.nvim_win_set_cursor, state.win, { state.first_item, 0 })
  else
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
  end
end

local function is_open(state)
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function same_app(left, right)
  return left.pid == right.pid and left.start_time == right.start_time
end

local function has_app(found, expected)
  for _, app in ipairs(found) do
    if same_app(app, expected) then
      return true
    end
  end
  return false
end

local function has_replacement(found, previous)
  local project = previous.project or previous.cwd
  for _, app in ipairs(found) do
    if (app.project or app.cwd) == project and not same_app(app, previous) then
      return true
    end
  end
  return false
end

local function refresh_until(state, done, remaining)
  if not is_open(state) then
    return
  end

  draw(state)
  if done(state.apps) or remaining <= 1 then
    return
  end

  vim.defer_fn(function()
    refresh_until(state, done, remaining - 1)
  end, 250)
end

local function move_view(state, direction)
  state.view = state.view + direction
  if state.view > #views then
    state.view = 1
  elseif state.view < 1 then
    state.view = #views
  end
  draw(state)
end

local function open_project_file(state)
  local item = current_item(state)
  if not item or item.kind ~= "path" then
    return
  end

  local path = item.path
  close(state)
  vim.cmd.edit(vim.fn.fnameescape(path))
end

local function map(state, lhs, callback, desc)
  vim.keymap.set("n", lhs, callback, {
    buffer = state.buf,
    desc = desc,
    noremap = true,
    silent = true,
  })
end

---@param root string
---@return table
function panel.open(root)
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines
  local max_width = math.max(editor_w - 4, 1)
  local max_height = math.max(editor_h - 4, 1)
  local desired_width = math.max(78, math.min(110, math.floor(editor_w * 0.72)))
  local desired_height = math.max(12, math.min(20, math.floor(editor_h * 0.45)))
  local width = math.min(desired_width, max_width)
  local height = math.min(desired_height, max_height)
  local row = math.max(math.floor((editor_h - height) / 2), 0)
  local col = math.max(math.floor((editor_w - width) / 2), 0)

  local buf = vim.api.nvim_create_buf(false, true)
  local state = {
    root = root,
    buf = buf,
    win = nil,
    view = 1,
    items_by_line = {},
    apps = {},
    first_item = nil,
  }

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "tapyr", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = title(root),
    title_pos = "center",
    footer = footer(),
    footer_pos = "center",
  })
  state.win = win

  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  draw(state)

  map(state, "<Tab>", function()
    move_view(state, 1)
  end, "Tapyr: next view")
  map(state, "<S-Tab>", function()
    move_view(state, -1)
  end, "Tapyr: previous view")
  map(state, "<CR>", function()
    open_project_file(state)
  end, "Tapyr: open project file")
  map(state, "r", function()
    draw(state)
  end, "Tapyr: refresh")
  map(state, "R", function()
    local app = selected_app(state)
    if app and apps.restart(app, state.root) then
      refresh_until(state, function(found)
        return not has_app(found, app) and has_replacement(found, app)
      end, 12)
    end
  end, "Tapyr: restart selected app")
  map(state, "x", function()
    local app = selected_app(state)
    if app and apps.stop(app) then
      refresh_until(state, function(found)
        return not has_app(found, app)
      end, 12)
    end
  end, "Tapyr: stop selected app")
  map(state, "o", function()
    local app = selected_app(state)
    if app then
      apps.open_in_browser(app.url)
    end
  end, "Tapyr: open selected app")
  map(state, "q", function()
    close(state)
  end, "Tapyr: close")
  map(state, "<Esc>", function()
    close(state)
  end, "Tapyr: close")

  return state
end

return panel
