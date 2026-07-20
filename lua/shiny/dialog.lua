local dialog = {}
local namespace = vim.api.nvim_create_namespace("shiny.dialog")

local function wipe(win, buf)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function footer()
  return {
    { " " },
    { "[q]", "DiagnosticOk" },
    { " cancel " },
  }
end

local function wrap(value, width)
  local lines = {}
  value = vim.trim(value)
  while vim.fn.strdisplaywidth(value) > width do
    local display_width = 0
    local last_space = 0
    local split
    for index = 1, vim.fn.strchars(value) do
      local character = vim.fn.strcharpart(value, index - 1, 1)
      display_width = display_width + vim.fn.strdisplaywidth(character)
      if display_width > width then
        split = last_space > 0 and last_space or math.max(index - 1, 1)
        break
      end
      if character:match("%s") then
        last_space = index
      end
    end
    lines[#lines + 1] = vim.trim(vim.fn.strcharpart(value, 0, split))
    value = vim.trim(vim.fn.strcharpart(value, split))
  end
  lines[#lines + 1] = value
  return lines
end

local function choose(parent, title, choices, callback, vertical, message)
  local selected = 1
  local original_blend = 0
  if parent and vim.api.nvim_win_is_valid(parent) then
    original_blend = vim.api.nvim_get_option_value("winblend", { win = parent })
    vim.api.nvim_set_option_value("winblend", 20, { win = parent })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "shiny-dialog", { buf = buf })

  local function label(index)
    local value = choices[index].label
    return index == selected and "[" .. value .. "]" or " " .. value .. " "
  end

  local content_width = vertical and 0 or math.max(#choices - 1, 0) * 3
  for index = 1, #choices do
    if vertical then
      content_width = math.max(content_width, #label(index))
    else
      content_width = content_width + #label(index)
    end
  end
  local max_width = math.max(vim.o.columns - 4, 1)
  local message_width = message and math.min(vim.fn.strdisplaywidth(message) + 2, 72) or 0
  local width = math.min(math.max(content_width, #title + 4, message_width), max_width)
  local message_lines = message and wrap(message, math.max(width - 2, 1)) or {}
  local message_height = #message_lines > 0 and #message_lines + 1 or 0
  local height = message_height + (vertical and #choices or 1)

  local function render(width)
    local lines = {}
    local offsets = {}
    for _, line in ipairs(message_lines) do
      lines[#lines + 1] = " " .. line
    end
    if #message_lines > 0 then
      lines[#lines + 1] = ""
    end
    local first_choice_line = #lines
    if vertical then
      for index = 1, #choices do
        local choice_label = label(index)
        local padding = math.max(math.floor((width - #choice_label) / 2), 0)
        lines[first_choice_line + index] = string.rep(" ", padding) .. choice_label
        offsets[index] = { first_choice_line + index - 1, padding, #choice_label }
      end
    else
      local parts = {}
      local column = 0
      for index = 1, #choices do
        local choice_label = label(index)
        offsets[index] = { 0, column, #choice_label }
        parts[#parts + 1] = choice_label
        column = column + #choice_label + 3
      end
      local line = table.concat(parts, "   ")
      local padding = math.max(math.floor((width - #line) / 2), 0)
      lines[first_choice_line + 1] = string.rep(" ", padding) .. line
      if padding > 0 then
        for _, offset in ipairs(offsets) do
          offset[2] = offset[2] + padding
        end
      end
      for _, offset in ipairs(offsets) do
        offset[1] = first_choice_line
      end
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    for index, offset in ipairs(offsets) do
      local options = {
        end_col = offset[2] + offset[3],
        hl_group = index == selected and "DiagnosticWarn"
          or choices[index].url and "DiagnosticInfo"
          or "Comment",
      }
      if choices[index].url and vim.fn.has("nvim-0.11") == 1 then
        options.url = choices[index].url
      end
      vim.api.nvim_buf_set_extmark(buf, namespace, offset[1], offset[2], options)
    end
  end

  render(width)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2), 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = footer(),
    footer_pos = "center",
    zindex = 100,
  })

  local closed = false
  local function close(value)
    if closed then
      return
    end
    closed = true
    wipe(win, buf)
    if parent and vim.api.nvim_win_is_valid(parent) then
      vim.api.nvim_set_option_value("winblend", original_blend, { win = parent })
      vim.api.nvim_set_current_win(parent)
    end
    callback(value)
  end

  local function move(direction)
    selected = ((selected - 1 + direction) % #choices) + 1
    render(width)
  end

  local options = { buffer = buf, silent = true }
  local previous_keys = vertical and { "k", "<Up>" } or { "h", "<Left>" }
  local next_keys = vertical and { "j", "<Down>" } or { "l", "<Right>" }
  for _, key in ipairs(previous_keys) do
    vim.keymap.set("n", key, function()
      move(-1)
    end, options)
  end
  for _, key in ipairs(next_keys) do
    vim.keymap.set("n", key, function()
      move(1)
    end, options)
  end
  vim.keymap.set("n", "<CR>", function()
    close(choices[selected].value)
  end, options)
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      close(nil)
    end, options)
  end
  return { buf = buf, win = win }
end

---@param parent? integer
---@param title string
---@param choices table[]
---@param callback fun(value: any?)
---@return table
function dialog.choose(parent, title, choices, callback)
  return choose(parent, title, choices, callback, false)
end

---@param parent? integer
---@param title string
---@param choices table[]
---@param callback fun(value: any?)
---@return table
function dialog.menu(parent, title, choices, callback)
  return choose(parent, title, choices, callback, true)
end

---@param parent? integer
---@param title string
---@param callback fun(confirmed: boolean)
---@return table
function dialog.confirm(parent, title, callback)
  return choose(parent, "Confirm", {
    { label = "Delete", value = true },
    { label = "Cancel", value = false },
  }, function(value)
    callback(value == true)
  end, false, title)
end

return dialog
