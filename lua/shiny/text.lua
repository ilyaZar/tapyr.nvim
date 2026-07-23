local text = {}

---@param value any
---@param width integer
---@return string
function text.shorten(value, width)
  value = tostring(value or "")
  width = math.max(width, 0)
  if vim.fn.strdisplaywidth(value) <= width then
    return value
  end
  local suffix = width > 3 and "..." or ""
  local available = width - #suffix
  local prefix = ""
  for length = 1, vim.fn.strchars(value) do
    local candidate = vim.fn.strcharpart(value, 0, length)
    if vim.fn.strdisplaywidth(candidate) > available then
      break
    end
    prefix = candidate
  end
  return prefix .. suffix
end

---@param value any
---@param width integer
---@return string
function text.column(value, width)
  value = text.shorten(value, width)
  return value .. string.rep(" ", math.max(width - vim.fn.strdisplaywidth(value), 0))
end

return text
