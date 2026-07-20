local view = {}

local create = require("shiny.rgolem.create")
local dialog = require("shiny.dialog")
local entries = require("shiny.rgolem.entries")
local launch = require("shiny.rgolem.launch")
local messages = require("shiny.messages")
local shelves = require("shiny.rgolem.shelves")
local text = require("shiny.text")

local prefixes = {
  apps = "new Golex app > ",
  shelves = "add shelf > ",
}

local function mode(state)
  state.golex_mode = state.golex_mode or "apps"
  return state.golex_mode
end

local function input_key(state)
  return "golex:" .. mode(state) .. ":input"
end

local function input_value(state)
  local item = state.line_by_key and state.line_by_key[input_key(state)]
  if item and vim.api.nvim_buf_is_valid(state.buf) then
    local line = vim.api.nvim_buf_get_lines(state.buf, item - 1, item, false)[1] or ""
    return line:sub(#prefixes[mode(state)] + 1)
  end
  return state.golex_input and state.golex_input[mode(state)] or ""
end

---@param state table
function view.capture(state)
  state.golex_input = state.golex_input or {}
  state.golex_input[mode(state)] = input_value(state)
end

---@param state table
---@param bar string
---@param register fun(line: integer, item: table, key: string?)
---@return string[]
function view.draw(state, bar, register)
  state.golex_input = state.golex_input or {}
  local current_mode = mode(state)
  local input = state.golex_input[current_mode] or ""
  local width = vim.api.nvim_win_get_width(state.win)
  local lines

  if current_mode == "shelves" then
    lines = {
      bar,
      "active shelf  " .. text.shorten(shelves.active(), math.max(width - 14, 1)),
      "",
      prefixes.shelves .. input,
      "",
      "shelves",
      string.rep("-", width),
    }
    register(4, { kind = "golex_input" }, input_key(state))
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
    return lines
  end

  local shelf = shelves.active()
  lines = {
    bar,
    "shelf  " .. text.shorten(shelf, math.max(width - 7, 1)),
    "",
    prefixes.apps .. input,
    "",
    "Golex apps",
    string.rep("-", width),
  }
  register(4, { kind = "golex_input" }, input_key(state))
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
  return lines
end

---@param state table
---@return table[]
function view.footer(state)
  if mode(state) == "shelves" then
    return {
      { label = "Enter", text = "add/select" },
      { label = "d", text = "delete shelf" },
      { label = "S", text = "Golex apps" },
      { label = "N", text = "new shelf" },
      { label = "q", text = "close" },
    }
  end
  return {
    { label = "Enter", text = "create/open" },
    { label = "d", text = "delete" },
    { label = "S", text = "shelves" },
    { label = "n", text = "next Golex app" },
    { label = "N", text = "new Golex app" },
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
    { label = "Open", value = "open", key = "o" },
    { label = "Recreate", value = "recreate", key = "R" },
  }, function(action)
    if action == "open" and launch.open(path, item.name) then
      api.close()
    elseif action == "recreate" then
      recreate(state, item, api)
    end
  end)
end

local function create_input(state, api)
  local input = input_value(state)
  local name, error_message = entries.resolve(input)
  if not name then
    messages.show(error_message, vim.log.levels.WARN)
    return
  end

  local shelf = shelves.active()
  if entries.exists(shelf, name) then
    recreate(state, { shelf = shelf, name = name }, api)
    return
  end

  state.golex_input.apps = ""
  create.at(shelf, name, false, api.refresh)
  api.draw(true)
end

local function add_shelf(state, api)
  local path = vim.trim(input_value(state))
  if path == "" then
    messages.show("Enter a shelf directory", vim.log.levels.WARN)
    return
  end
  shelves.add(path)
  state.golex_input.shelves = ""
  state.golex_mode = "apps"
  api.draw()
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
---@param api table
function view.next(state, api)
  if mode(state) ~= "apps" then
    return
  end
  view.capture(state)
  create.next(shelves.active(), api.refresh)
end

---@param state table
---@param api table
function view.edit_input(state, api)
  local line = state.line_by_key[input_key(state)]
  if not line then
    return
  end
  api.select(line)
  vim.api.nvim_set_option_value("modifiable", true, { buf = state.buf })
  vim.api.nvim_win_set_cursor(state.win, {
    line,
    #prefixes[mode(state)] + #input_value(state),
  })
  vim.cmd.startinsert()
end

return view
