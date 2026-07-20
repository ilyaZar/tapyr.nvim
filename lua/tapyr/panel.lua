local panel = {}

local apps = require("tapyr.apps")
local messages = require("tapyr.messages")
local registry = require("tapyr.registry")
local tasks = require("tapyr.tasks")
local text = require("tapyr.text")

local highlight_namespace = vim.api.nvim_create_namespace("tapyr.panel")
local selection_namespace = vim.api.nvim_create_namespace("tapyr.panel.selection")

local views = {
  { key = "apps", label = "Apps" },
  { key = "settings", label = "Settings" },
  { key = "help", label = "Help" },
}

local settings_items = {
  {
    name = "run app",
    mapping = "run",
    behavior = tasks.describe("run"),
  },
  {
    name = "restart app",
    mapping = "restart",
    behavior = tasks.describe("run"),
  },
  {
    name = "test app",
    mapping = "test",
    behavior = tasks.describe("test"),
  },
  {
    name = "panel",
    mapping = "panel",
    behavior = "open Tapyr panel",
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

local function view_bar(state)
  local parts = {}
  for index, view in ipairs(views) do
    local label = view.label
    if index == state.view then
      label = "[" .. label .. "]"
    else
      label = " " .. label .. " "
    end
    parts[#parts + 1] = label
  end
  local tabs = table.concat(parts, "  ")
  local hint = "Tab:views"
  local width = vim.api.nvim_win_get_width(state.win)
  return tabs .. string.rep(" ", math.max(width - #tabs - #hint, 2)) .. hint
end

local function footer()
  return {
    { " " },
    { "[Enter]", "DiagnosticOk" },
    { " app info  " },
    { "[R]", "DiagnosticOk" },
    { " (re)start  " },
    { "[X]", "DiagnosticOk" },
    { " stop  " },
    { "[b]", "DiagnosticOk" },
    { " browser  " },
    { "[r]", "DiagnosticOk" },
    { " refresh  " },
    { "[N]", "DiagnosticOk" },
    { " new app template  " },
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

local function register_item(state, line, item, key)
  item.key = key
  state.items_by_line[line] = item
  state.selectable_lines[#state.selectable_lines + 1] = line
  if key then
    state.line_by_key[key] = line
  end
end

local function draw_apps(state)
  local definitions, registry_notes = registry.load(state.root, state.current_app)
  local running, process_note = apps.find()
  local rows = apps.merge(definitions, running)
  state.rows = rows

  local lines = {
    view_bar(state),
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
    local key = row_key(row)
    register_item(state, line_number, {
      kind = "app",
      row = row,
    }, key)
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
  end

  return lines
end

local function draw_settings(state)
  local mappings = require("tapyr").config.mappings
  local lines = {
    view_bar(state),
    "",
    text.column("action", 18) .. " " .. text.column("key", 14) .. " behavior",
    string.rep("-", 74),
  }

  for _, item in ipairs(settings_items) do
    local line_number = #lines + 1
    register_item(state, line_number, {
      kind = "setting",
      mapping = item.mapping,
    }, "setting:" .. item.mapping)
    lines[#lines + 1] = text.column(item.name, 18)
      .. " "
      .. text.column(mapping_label(mappings[item.mapping]), 14)
      .. " "
      .. item.behavior
  end

  return lines
end

local function draw_help(state)
  local definitions, registry_notes = registry.load(state.root, state.current_app)
  local running, process_note = apps.find()
  local lines = {
    view_bar(state),
    "",
    "keys",
    "  Tab / Shift-Tab  cycle views forward or backward",
    "  j / k / arrows   move between selectable rows",
    "  Enter            show app information or edit a Settings mapping",
    "  R                start a stopped app or restart a running app",
    "  X                stop the selected running app",
    "  b                open the selected app in the default browser",
    "  r                refresh tracked and locally running apps",
    "  N                create a new app from the configured template",
    "  q / Esc          close the panel",
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

local function highlight_selection(state, line)
  vim.api.nvim_buf_clear_namespace(state.buf, selection_namespace, 0, -1)
  if line then
    vim.api.nvim_buf_set_extmark(state.buf, selection_namespace, line - 1, 0, {
      line_hl_group = "Visual",
    })
  end
end

local function select_line(state, line)
  local item = line and state.items_by_line[line] or nil
  if not item then
    return
  end

  state.moving = true
  pcall(vim.api.nvim_win_set_cursor, state.win, { line, 0 })
  state.moving = false
  state.selected_key = item.key
  state.selected_line = line
  highlight_selection(state, line)
end

local function nearest_line(state, target)
  local nearest
  local distance
  for _, line in ipairs(state.selectable_lines) do
    local candidate_distance = math.abs(line - target)
    if not distance or candidate_distance < distance then
      nearest = line
      distance = candidate_distance
    end
  end
  return nearest
end

local function constrain_cursor(state)
  if
    state.moving
    or not state.win
    or not vim.api.nvim_win_is_valid(state.win)
    or vim.tbl_isempty(state.selectable_lines)
  then
    return
  end

  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  if state.items_by_line[line] then
    select_line(state, line)
  else
    select_line(state, nearest_line(state, line))
  end
end

local function move_selection(state, direction)
  if vim.tbl_isempty(state.selectable_lines) then
    return
  end

  local current = state.selected_line or state.selectable_lines[1]
  local index = 1
  for candidate, line in ipairs(state.selectable_lines) do
    if line == current then
      index = candidate
      break
    end
  end
  index = math.max(1, math.min(#state.selectable_lines, index + direction))
  select_line(state, state.selectable_lines[index])
end

local function wipe_float(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function close(state)
  wipe_float(state.detail_win, state.detail_buf)
  wipe_float(state.win, state.buf)
end

local function draw(state, keep_selection)
  local selected_key = keep_selection and state.selected_key or nil

  state.items_by_line = {}
  state.line_by_key = {}
  state.selectable_lines = {}
  state.selected_key = nil
  state.selected_line = nil

  local view = views[state.view].key
  local lines
  if view == "apps" then
    lines = draw_apps(state)
  elseif view == "settings" then
    lines = draw_settings(state)
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
  local hint_start = lines[1]:find("Tab:views", 1, true)
  vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 0, hint_start - 1, {
    end_col = hint_start + 2,
    hl_group = "DiagnosticOk",
  })
  vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 0, hint_start + 2, {
    end_col = hint_start + 8,
    hl_group = "Comment",
  })
  if view ~= "help" then
    vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 2, 0, {
      end_col = #lines[3],
      hl_group = { "DiagnosticOk", "Bold" },
    })
  end

  local target_line = selected_key and state.line_by_key[selected_key] or state.selectable_lines[1]
  if target_line then
    select_line(state, target_line)
  else
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
    highlight_selection(state)
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

local function close_detail(state)
  wipe_float(state.detail_win, state.detail_buf)
  state.detail_win = nil
  state.detail_buf = nil

  if is_open(state) then
    vim.api.nvim_set_current_win(state.win)
    select_line(state, state.selected_line)
  end
end

local function detail_lines(row)
  local session = row.session
  local definition = row.definition
  local entrypoint = definition and definition.entrypoint or session and session.entrypoint
  if entrypoint and row.root ~= "" then
    entrypoint = vim.fs.relpath(row.root, entrypoint) or entrypoint
  end

  local provenance = definition and "tracked" or "untracked"
  local lifecycle = definition and "restart uses the Tapyr app definition"
    or "restart reuses the discovered process command"

  return {
    text.column("state", 12) .. row.state,
    text.column("app", 12) .. row.name,
    text.column("launch", 12) .. (session and session.launch or "-"),
    text.column("project", 12) .. (row.root ~= "" and row.root or "-"),
    text.column("entrypoint", 12) .. (entrypoint or "-"),
    text.column("url", 12) .. (session and session.url or "-"),
    text.column("port", 12)
      .. tostring(session and session.port or definition and tasks.port(definition) or "-"),
    text.column("pid", 12) .. tostring(session and session.pid or "-"),
    text.column("provenance", 12) .. provenance,
    text.column("lifecycle", 12) .. lifecycle,
  }
end

local function open_app_details(state, row)
  local lines = detail_lines(row)
  local width = math.min(math.max(70, math.floor(vim.o.columns * 0.68)), vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "tapyr", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2), 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "single",
    title = " Tapyr app ",
    title_pos = "center",
  })
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  state.detail_buf = buf
  state.detail_win = win

  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, function()
      close_detail(state)
    end, {
      buffer = buf,
      desc = "Tapyr: close app details",
      silent = true,
    })
  end
end

local function open_settings_file(state, mapping)
  local path = require("tapyr").config.settings_path
  path = type(path) == "string" and vim.fn.expand(path) or nil
  if not path or vim.fn.filereadable(path) ~= 1 then
    messages.show("Tapyr settings file is not readable", vim.log.levels.WARN)
    return
  end

  local target_line
  for line_number, line in ipairs(vim.fn.readfile(path)) do
    if line:match("^%s*" .. mapping .. "%s*=") then
      target_line = line_number
      break
    end
  end

  close(state)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if target_line then
    vim.api.nvim_win_set_cursor(0, { target_line, 0 })
  else
    messages.show("Could not find the " .. mapping .. " mapping", vim.log.levels.WARN)
  end
end

local function open_selected(state)
  local item = current_item(state)
  if not item then
    return
  end

  if item.kind == "app" then
    open_app_details(state, item.row)
  elseif item.kind == "setting" then
    open_settings_file(state, item.mapping)
  end
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
  local desired_width = math.max(78, math.min(116, math.floor(editor_w * 0.84)))
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

  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  draw(state)
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      constrain_cursor(state)
    end,
  })

  map(state, "<Tab>", function()
    move_view(state, 1)
  end, "Tapyr: next view")
  map(state, "<S-Tab>", function()
    move_view(state, -1)
  end, "Tapyr: previous view")
  map(state, "<CR>", function()
    open_selected(state)
  end, "Tapyr: open selected item")
  map(state, "N", function()
    require("tapyr.create").prompt(state.root, function()
      close(state)
    end)
  end, "Tapyr: create app")
  map(state, "j", function()
    move_selection(state, 1)
  end, "Tapyr: next item")
  map(state, "<Down>", function()
    move_selection(state, 1)
  end, "Tapyr: next item")
  map(state, "k", function()
    move_selection(state, -1)
  end, "Tapyr: previous item")
  map(state, "<Up>", function()
    move_selection(state, -1)
  end, "Tapyr: previous item")
  map(state, "gg", function()
    select_line(state, state.selectable_lines[1])
  end, "Tapyr: first item")
  map(state, "G", function()
    select_line(state, state.selectable_lines[#state.selectable_lines])
  end, "Tapyr: last item")
  map(state, "r", function()
    draw(state, true)
  end, "Tapyr: refresh")
  map(state, "R", function()
    local selected = selected_row(state)
    if not selected then
      return
    end
    local previous = selected.session
    apps.restart(selected, function()
      refresh_until(state, function(rows)
        if selected.definition then
          local current = row_for_id(rows, selected.definition.id)
          return current and current.session and not same_session(current.session, previous)
        end
        return previous and not has_session(rows, previous) and has_replacement(rows, previous)
      end, 12)
    end)
  end, "Tapyr: restart selected app")
  map(state, "X", function()
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
  map(state, "b", function()
    local selected = selected_row(state)
    if selected and selected.session then
      apps.open_in_browser(selected.session.url)
    elseif selected then
      messages.show(selected.name .. " is not running", vim.log.levels.WARN)
    end
  end, "Tapyr: open selected app in browser")
  map(state, "q", function()
    close(state)
  end, "Tapyr: close")
  map(state, "<Esc>", function()
    close(state)
  end, "Tapyr: close")

  return state
end

return panel
