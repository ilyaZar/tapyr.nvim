local footer = {}

local function chunks(items)
  local result = { { " " } }
  for index, item in ipairs(items) do
    result[#result + 1] = { "[" .. item.label .. "]", "DiagnosticOk" }
    result[#result + 1] = {
      " " .. item.text .. (index == #items and " " or "  "),
    }
  end
  return result
end

local function close(handle)
  if handle and handle.win and vim.api.nvim_win_is_valid(handle.win) then
    vim.api.nvim_win_close(handle.win, true)
  end
  if handle and handle.buf and vim.api.nvim_buf_is_valid(handle.buf) then
    vim.api.nvim_buf_delete(handle.buf, { force = true })
  end
end

local function wrap(items, width)
  local lines = {}
  local current = ""
  local limit = math.max(width - 2, 1)
  for _, item in ipairs(items) do
    local action = "[" .. item.label .. "] " .. item.text
    local candidate = current == "" and action or current .. "  " .. action
    if current ~= "" and vim.fn.strdisplaywidth(candidate) > limit then
      lines[#lines + 1] = current
      current = action
    else
      current = candidate
    end
  end
  if current ~= "" then
    lines[#lines + 1] = current
  end

  for index, line in ipairs(lines) do
    local padding = math.max(math.floor((width - vim.fn.strdisplaywidth(line)) / 2), 0)
    lines[index] = string.rep(" ", padding) .. line
  end
  return lines
end

local function highlight(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  for line_number, line in ipairs(lines) do
    local start = 1
    while true do
      local first, last = line:find("%b[]", start)
      if not first then
        break
      end
      vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticOk", line_number - 1, first - 1, last)
      start = last + 1
    end
  end
end

---@param parent integer
---@param handle? table
---@param items table[]
---@return table?
function footer.update(parent, handle, items)
  local width = vim.api.nvim_win_get_width(parent)
  local lines = wrap(items, width)
  if #lines <= 1 then
    close(handle)
    vim.api.nvim_win_set_config(parent, {
      footer = chunks(items),
      footer_pos = "center",
    })
    vim.api.nvim_set_option_value("scrolloff", 0, { win = parent })
    return nil
  end

  vim.api.nvim_win_set_config(parent, { footer = "" })
  local height = #lines
  if not handle or not vim.api.nvim_buf_is_valid(handle.buf) then
    handle = {
      buf = vim.api.nvim_create_buf(false, true),
    }
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = handle.buf })
    vim.api.nvim_set_option_value("filetype", "shiny-footer", { buf = handle.buf })
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = handle.buf })
  vim.api.nvim_buf_set_lines(handle.buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = handle.buf })
  highlight(handle.buf, lines)

  local config = {
    relative = "win",
    win = parent,
    width = width,
    height = height,
    row = math.max(vim.api.nvim_win_get_height(parent) - height, 0),
    col = 0,
    style = "minimal",
    focusable = false,
    noautocmd = true,
    zindex = 60,
  }
  if handle.win and vim.api.nvim_win_is_valid(handle.win) then
    config.win = nil
    config.noautocmd = nil
    vim.api.nvim_win_set_config(handle.win, config)
  else
    handle.win = vim.api.nvim_open_win(handle.buf, false, config)
    vim.api.nvim_set_option_value("wrap", false, { win = handle.win })
  end
  vim.api.nvim_set_option_value("scrolloff", height, { win = parent })
  return handle
end

---@param handle? table
function footer.close(handle)
  close(handle)
end

return footer
