local text = {}

---@param value any
---@param width integer
---@return string
function text.shorten(value, width)
  value = tostring(value or "")
  if #value <= width then
    return value
  end
  if width <= 3 then
    return value:sub(1, width)
  end
  return value:sub(1, width - 3) .. "..."
end

---@param value any
---@param width integer
---@return string
function text.column(value, width)
  value = text.shorten(value, width)
  return value .. string.rep(" ", math.max(width - #value, 0))
end

return text
