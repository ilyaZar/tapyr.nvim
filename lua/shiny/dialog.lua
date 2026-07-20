local dialog = {}

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
    { "[Enter]", "DiagnosticOk" },
    { " choose  " },
    { "[q]", "DiagnosticOk" },
    { " cancel " },
  }
end

---@param parent? integer
---@param title string
---@param choices table[]
---@param callback fun(value: any?)
---@param initial? integer
---@return table
function dialog.choose(parent, title, choices, callback, initial)
  local selected = initial or 1
  local original_blend = 0
  if parent and vim.api.nvim_win_is_valid(parent) then
    original_blend = vim.api.nvim_get_option_value("winblend", { win = parent })
    vim.api.nvim_set_option_value("winblend", 20, { win = parent })
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "shiny-dialog", { buf = buf })

  local function render()
    local parts = {}
    local offsets = {}
    local column = 0
    for index, choice in ipairs(choices) do
      local label = index == selected and "[" .. choice.label .. "]" or " " .. choice.label .. " "
      offsets[index] = { column, #label }
      parts[#parts + 1] = label
      column = column + #label + 3
    end
    local line = table.concat(parts, "   ")
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
    for index, offset in ipairs(offsets) do
      vim.api.nvim_buf_add_highlight(
        buf,
        -1,
        index == selected and "Visual" or "Comment",
        0,
        offset[1],
        offset[1] + offset[2]
      )
    end
    return #line
  end

  local width = math.max(render(), #title + 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(width, math.max(vim.o.columns - 4, 1)),
    height = 1,
    row = math.max(math.floor((vim.o.lines - 1) / 2), 0),
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
    render()
  end

  local options = { buffer = buf, silent = true }
  for _, key in ipairs({ "h", "<Left>" }) do
    vim.keymap.set("n", key, function()
      move(-1)
    end, options)
  end
  for _, key in ipairs({ "l", "<Right>" }) do
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
  for _, choice in ipairs(choices) do
    if choice.key then
      vim.keymap.set("n", choice.key, function()
        close(choice.value)
      end, options)
    end
  end

  return { buf = buf, win = win }
end

---@param parent? integer
---@param title string
---@param callback fun(confirmed: boolean)
---@return table
function dialog.confirm(parent, title, callback)
  return dialog.choose(parent, title, {
    { label = "Delete", value = true, key = "y" },
    { label = "Cancel", value = false, key = "n" },
  }, function(value)
    callback(value == true)
  end, 2)
end

return dialog
