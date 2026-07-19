local panel = {}

local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local registry = require("tapyr.registry")
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
    { "[n]", "DiagnosticOk" },
    { " new  " },
    { "[r]", "DiagnosticOk" },
    { " refresh  " },
    { "[R]", "DiagnosticOk" },
    { " start/restart  " },
    { "[x]", "DiagnosticOk" },
    { " stop  " },
    { "[o]", "DiagnosticOk" },
    { " open  " },
    { "[q]", "DiagnosticOk" },
    { " close " },
  }
end

local function title(root)
  return {
    { " Tapyr ", "FloatTitle" },
    { text.shorten(vim.fs.basename(root or vim.uv.cwd()), 52), "Comment" },
    { " ", "FloatTitle" },
  }
end

local function path_label(path, root)
  if not path or path == "" then
    return "-"
  end
  if path == root then
    return vim.fs.basename(root)
  end
  if vim.startswith(path, root .. "/") then
    return vim.fs.basename(root) .. path:sub(#root + 1)
  end
  return vim.fs.basename(path)
end

local function row_key(row)
  if row.definition then
    return row.definition.id
  end
  if row.session then
    return row.session.id or (row.session.pid .. ":" .. row.session.start_time)
  end
end

local function draw_apps(state)
  local definitions, registry_notes = registry.load(state.root, state.current_app)
  local running, process_note = apps.find()
  local rows = apps.merge(definitions, running)
  state.rows = rows

  local lines = {
    view_bar(state.view),
    "",
    text.column("state", 9)
      .. " "
      .. text.column("app", 20)
      .. " "
      .. text.column("port", 6)
      .. " "
      .. text.column("pid", 8)
      .. " "
      .. text.column("launch", 32)
      .. " project",
    string.rep("-", 100),
  }

  if vim.tbl_isempty(rows) then
    lines[#lines + 1] = "No tracked or running Shiny apps found"
    if process_note then
      lines[#lines + 1] = process_note
    end
    for _, note in ipairs(registry_notes) do
      lines[#lines + 1] = note
    end
    return lines
  end

  for _, row in ipairs(rows) do
    local session = row.session
    local line_number = #lines + 1
    state.items_by_line[line_number] = {
      kind = "app",
      row = row,
    }
    local key = row_key(row)
    if key then
      state.line_by_key[key] = line_number
    end
    lines[#lines + 1] = text.column(row.state, 9)
      .. " "
      .. text.column(row.name, 20)
      .. " "
      .. text.column(
        session and session.port or row.definition and tasks.port(row.definition) or "-",
        6
      )
      .. " "
      .. text.column(session and session.pid or "-", 8)
      .. " "
      .. text.column(session and session.launch or "-", 32)
      .. " "
      .. text.shorten(path_label(row.root, state.root), 34)
    state.first_item = state.first_item or line_number
  end

  return lines
end

local function draw_project(state)
  local mappings = require("tapyr").config.mappings
  local app = state.current_app
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
    else
      local line_number = #lines + 1
      local path
      if item.path == "app.py" and app then
        path = app.entrypoint
      else
        path = require("tapyr.project").file(app and app.root or state.root, item.path)
      end
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
  local definitions, registry_notes = registry.load(state.root, state.current_app)
  local running, process_note = apps.find()
  local lines = {
    view_bar(state.view),
    "",
    "keys",
    "  Tab       change view",
    "  n         create an app from the configured template",
    "  r         refresh apps",
    "  R         start or restart the selected app",
    "  x/o       stop or open the selected app",
    "  Enter     open a file from Project",
    "  q/Esc     close",
    "",
    "apps",
    "  tracked: " .. #definitions,
    "  running: " .. #running,
    "  context: " .. state.root,
  }

  if process_note then
    lines[#lines + 1] = "  " .. process_note
  end
  for _, note in ipairs(registry_notes) do
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

local function selected_row(state)
  local item = current_item(state)
  if not item or not item.row then
    messages.show("Select an app first", vim.log.levels.WARN)
    return nil
  end
  return item.row
end

local function close(state)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
end

local function draw(state, keep_selection)
  local item = keep_selection and current_item(state) or nil
  local selected_key = item and item.row and row_key(item.row) or nil

  state.items_by_line = {}
  state.line_by_key = {}
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

  local target_line = selected_key and state.line_by_key[selected_key] or state.first_item
  if target_line then
    pcall(vim.api.nvim_win_set_cursor, state.win, { target_line, 0 })
  else
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
  end
end

local function is_open(state)
  return state.win and vim.api.nvim_win_is_valid(state.win)
end

local function same_session(left, right)
  return left and right and left.pid == right.pid and left.start_time == right.start_time
end

local function row_for_id(rows, id)
  for _, row in ipairs(rows) do
    if row.definition and row.definition.id == id then
      return row
    end
  end
end

local function has_session(rows, expected)
  for _, row in ipairs(rows) do
    if same_session(row.session, expected) then
      return true
    end
  end
  return false
end

local function has_replacement(rows, previous)
  for _, row in ipairs(rows) do
    local session = row.session
    if session and session.id == previous.id and not same_session(session, previous) then
      return true
    end
  end
  return false
end

local function refresh_until(state, done, remaining)
  if not is_open(state) then
    return
  end

  draw(state, true)
  if done(state.rows or {}) or remaining <= 1 then
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
    silent = true,
  })
end

---@param root string
---@param current_app? TapyrAppDefinition
---@return table
function panel.open(root, current_app)
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
    current_app = current_app,
    buf = buf,
    view = 1,
  }

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
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
  map(state, "n", function()
    require("tapyr.create").prompt(state.root, function()
      close(state)
    end)
  end, "Tapyr: create app")
  map(state, "r", function()
    draw(state, true)
  end, "Tapyr: refresh")
  map(state, "R", function()
    local selected = selected_row(state)
    local previous = selected and selected.session
    if selected and apps.restart(selected) then
      refresh_until(state, function(rows)
        if selected.definition then
          local current = row_for_id(rows, selected.definition.id)
          return current and current.session and not same_session(current.session, previous)
        end
        return previous and not has_session(rows, previous) and has_replacement(rows, previous)
      end, 12)
    end
  end, "Tapyr: restart selected app")
  map(state, "x", function()
    local selected = selected_row(state)
    local session = selected and selected.session
    if not session then
      if selected then
        messages.show(selected.name .. " is not running", vim.log.levels.WARN)
      end
      return
    end
    if apps.stop(session) then
      refresh_until(state, function(rows)
        return not has_session(rows, session)
      end, 12)
    end
  end, "Tapyr: stop selected app")
  map(state, "o", function()
    local selected = selected_row(state)
    if selected and selected.session then
      apps.open_in_browser(selected.session.url)
    elseif selected then
      messages.show(selected.name .. " is not running", vim.log.levels.WARN)
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
