local panel = {}

local apps = require("shiny.apps")
local create = require("shiny.create")
local messages = require("shiny.messages")
local registry = require("shiny.registry")
local rgolem_view = require("shiny.rgolem.view")
local tasks = require("shiny.tasks")
local text = require("shiny.text")

local highlight_namespace = vim.api.nvim_create_namespace("shiny.panel")
local selection_namespace = vim.api.nvim_create_namespace("shiny.panel.selection")

local views = {
  { key = "apps", label = "Apps" },
  { key = "golex", label = "Golex" },
  { key = "settings", label = "Settings" },
  { key = "help", label = "Help" },
}

local actions = {
  views = {
    keys = { "<Tab>", "<S-Tab>" },
    label = "Tab / Shift+Tab",
    help = "next / previous view",
  },
  move = {
    keys = { "j", "<Down>", "k", "<Up>", "gg", "G" },
    label = "j / k / arrows",
    help = "move selection (gg / G for first / last)",
  },
  info = {
    keys = { "<CR>" },
    label = "Enter",
    footer = "app info",
    help = "use the selected item",
  },
  restart = {
    keys = { "R" },
    label = "R",
    footer = "(re)start",
    help = "start a stopped app or restart a running app",
  },
  stop = {
    keys = { "X" },
    label = "X",
    footer = "stop",
    help = "stop the selected running app",
  },
  browser = {
    keys = { "b" },
    label = "b",
    footer = "browser",
    help = "open the selected app in the default browser",
  },
  refresh = {
    keys = { "r" },
    label = "r",
    footer = "refresh",
    help = "refresh known and locally running apps",
  },
  new = {
    keys = { "N" },
    label = "N",
    footer = "new app template",
    help = "choose a configured app template",
  },
  close = {
    keys = { "q", "<Esc>" },
    label = "q / Esc",
    footer_label = "q",
    footer = "close",
    help = "close the panel",
  },
}

local help_actions = {
  "views",
  "move",
  "info",
  "restart",
  "stop",
  "browser",
  "refresh",
  "new",
  "close",
}

local about_links = {
  {
    label = "Project repository",
    url = "https://github.com/ilyaZar/shiny.nvim",
  },
  {
    label = "File an issue",
    url = "https://github.com/ilyaZar/shiny.nvim/issues",
  },
  {
    label = "Pull requests",
    url = "https://github.com/ilyaZar/shiny.nvim/pulls",
  },
  {
    label = "MIT License",
    url = "https://github.com/ilyaZar/shiny.nvim/blob/main/LICENSE",
  },
}

local settings_items = {
  {
    name = "run app",
    mapping = "run",
    behavior = "run with the detected backend",
  },
  {
    name = "restart app",
    mapping = "restart",
    behavior = "restart the managed backend task",
  },
  {
    name = "test app",
    mapping = "test",
    behavior = "test with the detected backend",
  },
  {
    name = "panel",
    mapping = "panel",
    behavior = "open Shiny panel",
  },
  {
    name = "document Golem",
    mapping = "document_reload",
    behavior = "R.nvim document and reload",
  },
  {
    name = "run Golem dev",
    mapping = "run_dev",
    behavior = "R.nvim project dev script",
  },
}

local golex_help = {
  { label = "Enter", help = "create input or open the selected Golex item" },
  { label = "N/i", help = "start or resume Golex name editing" },
  { label = "d", help = "delete the selected app or shelf after confirmation" },
  { label = "S", help = "switch between Golex apps and shelves" },
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

local function active_view(state)
  return views[state.view].key
end

local function footer_items(state)
  local view = active_view(state)
  if view == "golex" then
    return rgolem_view.footer(state)
  end
  if view == "settings" then
    return {
      { label = "Enter", text = "edit setting" },
      { label = "q", text = "close" },
    }
  end
  if view == "help" then
    return {
      { label = "Enter", text = "open link" },
      { label = "q", text = "close" },
    }
  end
  local items = {}
  for _, name in ipairs(help_actions) do
    local action = actions[name]
    if action.footer then
      items[#items + 1] = {
        label = action.footer_label or action.label,
        text = action.footer,
      }
    end
  end
  return items
end

local function title(root)
  return {
    { " Shiny ", "FloatTitle" },
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

local function app_snapshot(state)
  local definitions, registry_notes = registry.load(state.root, state.current_app)
  local running, process_note = apps.find()
  return apps.merge(definitions, running), registry_notes, process_note
end

local function draw_apps(state)
  local rows, registry_notes, process_note = app_snapshot(state)
  state.rows = rows
  state.awaiting_pid = false
  local width = vim.api.nvim_win_get_width(state.win)
  local compact = width < 100

  local lines = { view_bar(state), "" }
  if compact then
    local app_width = math.max(width - 27, 8)
    lines[#lines + 1] = text.column("state", 9)
      .. " "
      .. text.column("backend", 8)
      .. " "
      .. text.column("app", app_width)
      .. " port"
    lines[#lines + 1] = string.rep("-", width)
  else
    lines[#lines + 1] = text.column("state", 9)
      .. " "
      .. text.column("backend", 8)
      .. " "
      .. text.column("app", 18)
      .. " "
      .. text.column("port", 6)
      .. " "
      .. text.column("pid", 8)
      .. " "
      .. text.column("launch", 32)
      .. " project"
    lines[#lines + 1] = string.rep("-", 100)
  end

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
    local backend_name = row.definition and row.definition.backend or row.session.backend
    if
      not process_note
      and session
      and session.managed
      and not session.pid
      and backend_name == "python"
    then
      state.awaiting_pid = true
    end
    local port = session and session.port or row.definition and tasks.port(row.definition) or "-"
    if compact then
      local app_width = math.max(width - 27, 8)
      lines[#lines + 1] = text.column(row.state, 9)
        .. " "
        .. text.column(backend_name, 8)
        .. " "
        .. text.column(row.name, app_width)
        .. " "
        .. text.shorten(port, 6)
      lines[#lines + 1] = "  "
        .. text.column("launch", 9)
        .. text.shorten(session and session.launch or "-", math.max(width - 11, 1))
      lines[#lines + 1] = "  "
        .. text.column("project", 9)
        .. text.shorten(path_label(row.root, state.root), math.max(width - 11, 1))
    else
      lines[#lines + 1] = text.column(row.state, 9)
        .. " "
        .. text.column(backend_name, 8)
        .. " "
        .. text.column(row.name, 18)
        .. " "
        .. text.column(port, 6)
        .. " "
        .. text.column(session and session.pid or "-", 8)
        .. " "
        .. text.column(session and session.launch or "-", 32)
        .. " "
        .. text.shorten(path_label(row.root, state.root), 34)
    end
  end

  return lines
end

local function draw_settings(state)
  local config = require("shiny").config
  local width = vim.api.nvim_win_get_width(state.win)
  local lines = {
    view_bar(state),
    "",
    "Mappings",
    text.column("action", 18) .. " " .. text.column("key", 14) .. " behavior",
    string.rep("-", width),
  }

  for _, item in ipairs(settings_items) do
    local line_number = #lines + 1
    register_item(state, line_number, {
      kind = "setting",
      setting = item.mapping,
      setting_label = item.mapping .. " mapping",
    }, "setting:" .. item.mapping)
    lines[#lines + 1] = text.column(item.name, 18)
      .. " "
      .. text.column(mapping_label(config.mappings[item.mapping]), 14)
      .. " "
      .. text.shorten(item.behavior, math.max(width - 34, 1))
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Creation templates"
  lines[#lines + 1] = text.column("name", 18) .. " " .. text.column("provider", 12) .. " source"
  lines[#lines + 1] = string.rep("-", width)
  for index, template in ipairs(config.creation_templates) do
    local provider, description = create.describe(template)
    local line_number = #lines + 1
    register_item(state, line_number, {
      kind = "setting",
      setting = "creation_templates",
      setting_label = "creation_templates setting",
    }, "template:" .. index .. ":" .. template.name)
    lines[#lines + 1] = text.column(template.name, 18)
      .. " "
      .. text.column(provider, 12)
      .. " "
      .. text.shorten(description, math.max(width - 32, 1))
  end

  return lines
end

local function draw_help(state)
  local rows, registry_notes, process_note = app_snapshot(state)
  local counts = {
    golem = 0,
    python = 0,
    running = 0,
    stopped = 0,
  }
  for _, row in ipairs(rows) do
    counts[row.state] = counts[row.state] + 1
    local row_backend = row.definition and row.definition.backend or row.session.backend
    if counts[row_backend] then
      counts[row_backend] = counts[row_backend] + 1
    end
  end

  local lines = {
    view_bar(state),
    "",
    "About",
  }

  for _, link in ipairs(about_links) do
    local line_number = #lines + 1
    register_item(state, line_number, {
      kind = "link",
      url = link.url,
    }, "link:" .. link.url)
    lines[#lines + 1] = "  " .. link.label
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Keys"
  for _, name in ipairs(help_actions) do
    local action = actions[name]
    lines[#lines + 1] = "  " .. text.column(action.label, 19) .. action.help
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "Golex keys"
  for _, action in ipairs(golex_help) do
    lines[#lines + 1] = "  " .. text.column(action.label, 19) .. action.help
  end

  local workspace = vim.fn.fnamemodify(state.root, ":~")
  workspace = text.shorten(workspace, math.max(vim.api.nvim_win_get_width(state.win) - 14, 10))
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Apps"
  lines[#lines + 1] = "  " .. text.column("running", 12) .. counts.running
  lines[#lines + 1] = "  " .. text.column("stopped", 12) .. counts.stopped
  lines[#lines + 1] = "  " .. text.column("Python", 12) .. counts.python
  lines[#lines + 1] = "  " .. text.column("Golem", 12) .. counts.golem
  lines[#lines + 1] = "  " .. text.column("workspace", 12) .. workspace

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

local function selected_app(state)
  if active_view(state) ~= "apps" then
    return nil
  end
  return selected_row(state)
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
  rgolem_view.close_input(state)
  wipe_float(state.detail_win, state.detail_buf)
  state.detail_refresh = nil
  require("shiny.footer").close(state.footer)
  wipe_float(state.win, state.buf)
end

local function draw(state, keep_selection)
  local selected_key = keep_selection and state.selected_key or nil

  state.items_by_line = {}
  state.line_by_key = {}
  state.selectable_lines = {}
  state.selected_key = nil
  state.selected_line = nil

  local view = active_view(state)
  local lines
  local view_highlights
  if view == "apps" then
    lines = draw_apps(state)
  elseif view == "golex" then
    lines, view_highlights = rgolem_view.draw(state, view_bar(state), function(line, item, key)
      register_item(state, line, item, key)
    end)
  elseif view == "settings" then
    lines = draw_settings(state)
  else
    lines = draw_help(state)
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = state.buf })
  state.footer = require("shiny.footer").update(state.win, state.footer, footer_items(state))

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
  if view == "apps" then
    vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, 2, 0, {
      end_col = #lines[3],
      hl_group = { "DiagnosticOk", "Bold" },
    })
  elseif view == "settings" then
    for line_number, line in ipairs(lines) do
      if line == "Mappings" or line == "Creation templates" then
        vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, line_number - 1, 0, {
          end_col = #line,
          hl_group = { "DiagnosticOk", "Bold" },
        })
      end
    end
  elseif view == "golex" then
    for _, highlight in ipairs(view_highlights) do
      vim.api.nvim_buf_set_extmark(
        state.buf,
        highlight_namespace,
        highlight.line - 1,
        highlight.start_col,
        {
          end_col = highlight.end_col,
          hl_group = highlight.hl_group,
        }
      )
    end
  else
    for line_number, line in ipairs(lines) do
      if line == "Keys" or line == "Golex keys" or line == "Apps" or line == "About" then
        vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, line_number - 1, 0, {
          end_col = #line,
          hl_group = { "DiagnosticOk", "Bold" },
        })
      end
    end
    for line_number, item in pairs(state.items_by_line) do
      if item.kind == "link" then
        local options = {
          end_col = #lines[line_number],
          hl_group = "DiagnosticInfo",
        }
        if vim.fn.has("nvim-0.11") == 1 then
          options.url = item.url
        end
        vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, line_number - 1, 2, options)
      end
    end
  end

  local target_line = selected_key and state.line_by_key[selected_key] or state.selectable_lines[1]
  if target_line then
    select_line(state, target_line)
  else
    pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 0 })
    highlight_selection(state)
  end

  if state.detail_refresh then
    state.detail_refresh()
  end
  if
    view == "apps"
    and state.awaiting_pid
    and state.pid_refresh_remaining > 0
    and not state.pid_refresh_scheduled
  then
    state.pid_refresh_scheduled = true
    state.pid_refresh_remaining = state.pid_refresh_remaining - 1
    vim.defer_fn(function()
      state.pid_refresh_scheduled = nil
      if state.win and vim.api.nvim_win_is_valid(state.win) and active_view(state) == "apps" then
        draw(state, true)
      end
    end, 500)
  end
end

local function golex_api(state)
  return {
    draw = function(keep_selection)
      draw(state, keep_selection)
    end,
    refresh = function()
      draw(state, true)
    end,
    close = function()
      close(state)
    end,
    select = function(line)
      select_line(state, line)
    end,
  }
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
  if active_view(state) == "golex" then
    rgolem_view.capture(state)
  end
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
  state.detail_refresh = nil

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
  local lifecycle = definition and "restart uses the Shiny app definition"
    or "restart reuses the discovered process command"

  return {
    text.column("state", 12) .. row.state,
    text.column("backend", 12)
      .. (definition and definition.backend or session and session.backend or "-"),
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
  local key = row_key(row)
  local width = math.min(math.max(70, math.floor(vim.o.columns * 0.68)), vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "shiny", { buf = buf })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2), 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "single",
    title = " Shiny app ",
    title_pos = "center",
    footer = {
      { " " },
      { "[r]", "DiagnosticOk" },
      { " refresh  " },
      { "[q]", "DiagnosticOk" },
      { " close " },
    },
    footer_pos = "center",
  })
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  state.detail_buf = buf
  state.detail_win = win
  state.detail_refresh = function()
    local line = state.line_by_key[key]
    local item = line and state.items_by_line[line]
    if not item or not item.row then
      messages.show("App is no longer available", vim.log.levels.WARN)
      close_detail(state)
      return
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = state.detail_buf })
    vim.api.nvim_buf_set_lines(state.detail_buf, 0, -1, false, detail_lines(item.row))
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.detail_buf })
  end

  vim.keymap.set("n", "r", function()
    state.pid_refresh_remaining = 60
    draw(state, true)
  end, {
    buffer = buf,
    desc = "Shiny: refresh app details",
    silent = true,
  })

  for _, lhs in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", lhs, function()
      close_detail(state)
    end, {
      buffer = buf,
      desc = "Shiny: close app details",
      silent = true,
    })
  end
end

local function open_settings_file(state, setting, setting_label)
  local path = require("shiny").config.settings_path
  path = type(path) == "string" and vim.fn.expand(path) or nil
  if not path or vim.fn.filereadable(path) ~= 1 then
    messages.show("Shiny settings file is not readable", vim.log.levels.WARN)
    return
  end

  local target_line
  for line_number, line in ipairs(vim.fn.readfile(path)) do
    if line:match("^%s*" .. setting .. "%s*=") then
      target_line = line_number
      break
    end
  end

  close(state)
  vim.cmd.edit(vim.fn.fnameescape(path))
  if target_line then
    vim.api.nvim_win_set_cursor(0, { target_line, 0 })
  else
    messages.show("Could not find the " .. setting_label, vim.log.levels.WARN)
  end
end

local function open_selected(state)
  local item = current_item(state)
  if not item then
    return
  end

  if vim.startswith(item.kind, "golex_") then
    rgolem_view.open_selected(state, item, state.golex_api)
  elseif item.kind == "app" then
    open_app_details(state, item.row)
  elseif item.kind == "setting" then
    open_settings_file(state, item.setting, item.setting_label)
  elseif item.kind == "link" then
    vim.ui.open(item.url)
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
---@param current_app? ShinyAppDefinition
---@param initial_view? string
---@return table
function panel.open(root, current_app, initial_view)
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines
  local max_width = math.max(editor_w - 4, 1)
  local max_height = math.max(editor_h - 4, 1)
  local desired_width = math.max(78, math.min(116, math.floor(editor_w * 0.84)))
  local desired_height = math.max(12, math.min(24, math.floor(editor_h * 0.55)))
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
    pid_refresh_remaining = 60,
  }
  for index, view in ipairs(views) do
    if view.key == initial_view then
      state.view = index
      break
    end
  end

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "shiny", { buf = buf })

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
  })
  state.win = win
  state.golex_api = golex_api(state)

  vim.api.nvim_set_option_value("cursorline", false, { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })

  draw(state)
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = function()
      constrain_cursor(state)
    end,
  })

  map(state, actions.views.keys[1], function()
    move_view(state, 1)
  end, "Shiny: next view")
  map(state, actions.views.keys[2], function()
    move_view(state, -1)
  end, "Shiny: previous view")
  map(state, actions.info.keys[1], function()
    open_selected(state)
  end, "Shiny: open selected item")
  map(state, actions.new.keys[1], function()
    if active_view(state) == "apps" then
      create.prompt(state.win, function()
        close(state)
      end)
    elseif active_view(state) == "golex" then
      rgolem_view.new_input(state, state.golex_api)
    end
  end, "Shiny: create in current view")
  map(state, "i", function()
    if active_view(state) == "golex" then
      rgolem_view.new_input(state, state.golex_api)
    end
  end, "Shiny: edit Golex input")
  map(state, actions.move.keys[1], function()
    move_selection(state, 1)
  end, "Shiny: next item")
  map(state, actions.move.keys[2], function()
    move_selection(state, 1)
  end, "Shiny: next item")
  map(state, actions.move.keys[3], function()
    move_selection(state, -1)
  end, "Shiny: previous item")
  map(state, actions.move.keys[4], function()
    move_selection(state, -1)
  end, "Shiny: previous item")
  map(state, actions.move.keys[5], function()
    select_line(state, state.selectable_lines[1])
  end, "Shiny: first item")
  map(state, actions.move.keys[6], function()
    select_line(state, state.selectable_lines[#state.selectable_lines])
  end, "Shiny: last item")
  map(state, actions.refresh.keys[1], function()
    if active_view(state) == "apps" then
      state.pid_refresh_remaining = 60
      draw(state, true)
    end
  end, "Shiny: refresh")
  map(state, actions.restart.keys[1], function()
    local selected = selected_app(state)
    if not selected then
      return
    end
    state.pid_refresh_remaining = 60
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
  end, "Shiny: restart selected app")
  map(state, actions.stop.keys[1], function()
    local selected = selected_app(state)
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
  end, "Shiny: stop selected app")
  map(state, actions.browser.keys[1], function()
    local selected = selected_app(state)
    if selected and selected.session then
      apps.open_in_browser(selected.session.url)
    elseif selected then
      messages.show(selected.name .. " is not running", vim.log.levels.WARN)
    end
  end, "Shiny: open selected app in browser")
  map(state, "d", function()
    if active_view(state) == "golex" then
      rgolem_view.delete_selected(state, current_item(state), state.golex_api)
    end
  end, "Shiny: delete selected Golex item")
  map(state, "S", function()
    if active_view(state) == "golex" then
      rgolem_view.toggle_shelves(state, state.golex_api)
    end
  end, "Shiny: switch Golex view")
  map(state, actions.close.keys[1], function()
    close(state)
  end, "Shiny: close")
  map(state, actions.close.keys[2], function()
    close(state)
  end, "Shiny: close")

  return state
end

return panel
