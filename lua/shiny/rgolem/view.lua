local view = {}

local create = require("shiny.rgolem.create")
local dialog = require("shiny.dialog")
local entries = require("shiny.rgolem.entries")
local launch = require("shiny.rgolem.launch")
local messages = require("shiny.messages")
local name = require("shiny.rgolem.name")
local shelves = require("shiny.rgolem.shelves")
local text = require("shiny.text")

local prefixes = {
  apps = "new Golex app name > ",
  shelves = "add new shelf name > ",
}
local name_error_timeout = 6000

local function mode(state)
  state.golex_mode = state.golex_mode or "apps"
  return state.golex_mode
end

local function input_key(state)
  return "golex:" .. mode(state) .. ":input"
end

local function input_value(state)
  local edit = state.golex_edit
  if edit and edit.mode == mode(state) and vim.api.nvim_buf_is_valid(edit.buf) then
    return vim.api.nvim_buf_get_lines(edit.buf, 0, 1, false)[1] or ""
  end
  local item = state.line_by_key and state.line_by_key[input_key(state)]
  if item and vim.api.nvim_buf_is_valid(state.buf) then
    local line = vim.api.nvim_buf_get_lines(state.buf, item - 1, item, false)[1] or ""
    return line:sub(#prefixes[mode(state)] + 1)
  end
  return state.golex_input and state.golex_input[mode(state)] or ""
end

local function highlight(line, start_col, value, group)
  return {
    line = line,
    start_col = start_col,
    end_col = start_col + #value,
    hl_group = group,
  }
end

---@param state table
function view.capture(state)
  state.golex_input = state.golex_input or {}
  state.golex_input[mode(state)] = input_value(state)
end

---@param state table
---@param bar string
---@param register fun(line: integer, item: table, key: string?)
---@return string[], table[]
function view.draw(state, bar, register)
  state.golex_input = state.golex_input or {}
  local current_mode = mode(state)
  local input = state.golex_input[current_mode] or ""
  local width = vim.api.nvim_win_get_width(state.win)
  local highlights = {}

  if current_mode == "shelves" then
    local active_label = "currently active shelf: "
    local back_hint = "Back to Golex apps: [S]"
    if width < #active_label + #back_hint + 2 then
      active_label = "active shelf: "
      back_hint = "[S] apps"
    end
    if width < #active_label + #back_hint + 2 then
      active_label = ""
    end
    if width < #back_hint + 2 then
      back_hint = text.shorten("[S]", width)
    end
    local path_width = math.max(width - #active_label - #back_hint - 1, 0)
    local active_path = text.shorten(shelves.active(), path_width)
    local left = active_label .. active_path
    local gap = string.rep(" ", math.max(width - vim.fn.strdisplaywidth(left) - #back_hint, 0))
    local status = left .. gap .. back_hint
    local lines = {
      bar,
      status,
      "",
      "Shelf selection",
      string.rep("-", width),
    }
    highlights[#highlights + 1] = highlight(2, 0, active_label, "Statement")
    highlights[#highlights + 1] = highlight(2, #active_label, active_path, "DiagnosticOk")
    highlights[#highlights + 1] = highlight(2, #status - #back_hint, back_hint, "DiagnosticError")
    highlights[#highlights + 1] = highlight(4, 0, "Shelf selection", { "DiagnosticOk", "Bold" })
    for index, path in ipairs(shelves.all()) do
      local line = #lines + 1
      local marker = index == shelves.active_index() and "* " or "  "
      lines[line] = marker .. text.shorten(path, math.max(width - 2, 1))
      register(line, {
        kind = "golex_shelf",
        index = index,
        path = path,
      }, "golex:shelf:" .. path)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Add new shelf"
    highlights[#highlights + 1] = highlight(#lines, 0, "Add new shelf", { "DiagnosticOk", "Bold" })
    lines[#lines + 1] = string.rep("-", width)
    lines[#lines + 1] = prefixes.shelves .. input
    register(#lines, { kind = "golex_input" }, input_key(state))
    highlights[#highlights + 1] = highlight(#lines, 0, lines[#lines], "DiagnosticInfo")
    return lines, highlights
  end

  local shelf = shelves.active()
  local shelf_label = "path to selected shelf: "
  local shelf_path = text.shorten(shelf, math.max(width - #shelf_label, 1))
  local lines = {
    bar,
    shelf_label .. shelf_path,
    "",
    "Add new Golex app",
    string.rep("-", width),
    prefixes.apps .. input,
    "",
    "Golex apps",
    string.rep("-", width),
  }
  highlights = {
    highlight(2, 0, shelf_label, "Statement"),
    highlight(2, #shelf_label, shelf_path, "DiagnosticOk"),
    highlight(4, 0, "Add new Golex app", { "DiagnosticOk", "Bold" }),
    highlight(6, 0, lines[6], "DiagnosticInfo"),
    highlight(8, 0, "Golex apps", { "DiagnosticOk", "Bold" }),
  }
  register(6, { kind = "golex_input" }, input_key(state))
  local found = entries.scan(shelf)
  if vim.tbl_isempty(found) then
    lines[#lines + 1] = "No Golex apps in this shelf"
  else
    for _, name in ipairs(found) do
      local line = #lines + 1
      lines[line] = text.shorten(name, width)
      register(line, {
        kind = "golex_entry",
        name = name,
        shelf = shelf,
      }, "golex:entry:" .. shelf .. ":" .. name)
    end
  end
  return lines, highlights
end

---@param state table
---@return table[]
function view.footer(state)
  if mode(state) == "shelves" then
    return {
      { label = "Enter", text = "select" },
      { label = "d", text = "delete shelf" },
      { label = "S", text = "Golex apps" },
      { label = "N/i", text = "edit shelf name/path" },
      { label = "q", text = "close" },
    }
  end
  return {
    { label = "Enter", text = "open w/ external editor" },
    { label = "d", text = "delete" },
    { label = "S", text = "shelves" },
    { label = "N/i", text = "edit Golex app name" },
    { label = "q", text = "close" },
  }
end

local function entry_path(item)
  local path, error_message = entries.path(item.shelf, item.name)
  if not path then
    messages.show(error_message, vim.log.levels.ERROR)
  end
  return path
end

local function recreate(state, item, api)
  local path = entry_path(item)
  if not path then
    return
  end
  dialog.confirm(
    state.win,
    "Delete " .. path .. " recursively and recreate it?",
    function(confirmed)
      if confirmed then
        create.at(item.shelf, item.name, true, api.refresh)
      end
    end
  )
end

local function open_entry(state, item, api)
  local path = entry_path(item)
  if not path then
    return
  end
  dialog.choose(state.win, item.name, {
    { label = "Open", value = "open" },
    { label = "Recreate", value = "recreate" },
  }, function(action)
    if action == "open" and launch.open(path, item.name) then
      api.close()
    elseif action == "recreate" then
      recreate(state, item, api)
    end
  end)
end

local function resolve_name(value)
  local package_name, error_message = name.resolve(value)
  if not package_name then
    messages.show(error_message, vim.log.levels.WARN, name_error_timeout)
  end
  return package_name
end

local function create_input(state, api, package_name)
  package_name = package_name or resolve_name(input_value(state))
  if not package_name then
    return
  end

  local shelf = shelves.active()
  if entries.exists(shelf, package_name) then
    recreate(state, { shelf = shelf, name = package_name }, api)
    return
  end

  state.golex_input.apps = ""
  create.at(shelf, package_name, false, api.refresh)
  api.draw(true)
end

local function add_shelf(state, api)
  local input = vim.trim(input_value(state))
  if input == "" then
    messages.show("Enter a shelf name or path", vim.log.levels.WARN)
    return
  end
  local cwd = vim.fs.normalize(vim.uv.cwd()):gsub("[/\\]+$", "")
  local rooted = input:match("^[/\\]") or input:match("^%a:[/\\]")
  local separator = rooted and "" or package.config:sub(1, 1)
  local default = cwd .. separator .. input
  vim.ui.input({
    prompt = "New shelf path: ",
    default = default,
    completion = "dir",
  }, function(path)
    path = path and vim.trim(path) or ""
    if path == "" then
      return
    end
    shelves.add(path)
    state.golex_input.shelves = ""
    state.golex_mode = "apps"
    api.draw()
  end)
end

---@param state table
---@param item? table
---@param api table
function view.open_selected(state, item, api)
  view.capture(state)
  if not item then
    return
  end
  if item.kind == "golex_input" then
    if mode(state) == "shelves" then
      add_shelf(state, api)
    else
      create_input(state, api)
    end
  elseif item.kind == "golex_entry" then
    open_entry(state, item, api)
  elseif item.kind == "golex_shelf" then
    shelves.select(item.index)
    state.golex_mode = "apps"
    api.draw()
  end
end

---@param state table
---@param item? table
---@param api table
function view.delete_selected(state, item, api)
  view.capture(state)
  if not item then
    return
  end
  if item.kind == "golex_entry" then
    local path = entry_path(item)
    if not path then
      return
    end
    dialog.confirm(state.win, "Delete " .. path .. " recursively?", function(confirmed)
      if not confirmed then
        return
      end
      local deleted, error_message = entries.delete(item.shelf, item.name)
      if deleted then
        messages.show("Deleted " .. item.name)
        api.draw()
      else
        messages.show(error_message, vim.log.levels.ERROR)
      end
    end)
  elseif item.kind == "golex_shelf" then
    dialog.confirm(
      state.win,
      "Delete shelf " .. item.path .. " and every project under it recursively?",
      function(confirmed)
        if not confirmed then
          return
        end
        local deleted, error_message = shelves.delete(item.index)
        if deleted then
          messages.show("Deleted shelf " .. item.path)
          api.draw()
        else
          messages.show(error_message, vim.log.levels.WARN)
        end
      end
    )
  end
end

---@param state table
---@param api table
function view.toggle_shelves(state, api)
  view.capture(state)
  state.golex_mode = mode(state) == "apps" and "shelves" or "apps"
  api.draw()
end

---@param state table
local function discard_input(state)
  local edit = state.golex_edit
  state.golex_edit = nil
  if edit and edit.win and vim.api.nvim_win_is_valid(edit.win) then
    vim.api.nvim_win_close(edit.win, true)
  end
  if edit and edit.buf and vim.api.nvim_buf_is_valid(edit.buf) then
    vim.api.nvim_buf_delete(edit.buf, { force = true })
  end
end

---@param state table
function view.close_input(state)
  discard_input(state)
end

---@param state table
---@param api table
function view.new_input(state, api)
  view.capture(state)
  view.close_input(state)

  local current_mode = mode(state)
  if current_mode == "apps" and state.golex_input.apps == "" then
    state.golex_input.apps = name.numbered(entries.next_number(shelves.active()))
  end
  api.draw(true)

  local line = state.line_by_key[input_key(state)]
  if not line then
    return
  end
  api.select(line)

  local value = state.golex_input[current_mode]
  local prefix = prefixes[current_mode]
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { value })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "shiny-input", { buf = buf })
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "win",
    win = state.win,
    width = math.max(vim.api.nvim_win_get_width(state.win) - #prefix, 1),
    height = 1,
    row = line - 1,
    col = #prefix,
    style = "minimal",
    zindex = 70,
  })
  vim.api.nvim_set_option_value("winhighlight", "Normal:Visual,EndOfBuffer:Visual", { win = win })
  vim.api.nvim_win_set_cursor(win, { 1, #value })
  state.golex_edit = { mode = current_mode, buf = buf, win = win }

  local closed = false
  local last_value = value
  local restoring = false
  local function finish(submit)
    if closed then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if #lines == 1 then
      last_value = lines[1]
    end
    state.golex_input[current_mode] = last_value

    local package_name
    if submit and current_mode == "apps" then
      package_name = resolve_name(last_value)
      if not package_name then
        return
      end
    elseif submit and vim.trim(last_value) == "" then
      messages.show("Enter a shelf name or path", vim.log.levels.WARN)
      return
    end

    closed = true
    discard_input(state)
    if not vim.api.nvim_win_is_valid(state.win) then
      return
    end
    vim.api.nvim_set_current_win(state.win)
    api.draw(true)
    if submit then
      if current_mode == "apps" then
        create_input(state, api, package_name)
      else
        add_shelf(state, api)
      end
    end
  end
  state.golex_edit.finish = finish

  vim.api.nvim_create_autocmd("TextChangedI", {
    buffer = buf,
    callback = function()
      if restoring then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      if #lines == 1 then
        last_value = lines[1]
        return
      end
      restoring = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { last_value })
      vim.api.nvim_win_set_cursor(win, { 1, #last_value })
      restoring = false
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave" }, {
    buffer = buf,
    once = true,
    callback = function()
      finish(false)
    end,
  })
  vim.keymap.set("i", "<CR>", function()
    finish(true)
  end, {
    buffer = buf,
    desc = "Shiny: submit Golex input",
    silent = true,
  })
  vim.cmd.startinsert()
end

return view
