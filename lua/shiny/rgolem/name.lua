local name = {}

---@param value integer
---@return string
function name.numbered(value)
  return string.format("golex%02d", value)
end

---@param value string
---@return string?, string?
function name.validate(value)
  value = vim.trim(value)
  if value == "" then
    return nil, "Enter an R package name"
  end
  if not value:match("^[A-Za-z][A-Za-z0-9.]+$") or value:sub(-1) == "." then
    return nil,
      "Use 2+ characters: an ASCII letter first, then ASCII letters, numbers, or dots; no spaces or trailing dot"
  end
  return value
end

---@param value string
---@return string?, string?
function name.resolve(value)
  value = vim.trim(value)
  if value == "" then
    return nil, "Enter a Golex app name or number"
  end

  local number = value:match("^%d+$")
  if number then
    return name.numbered(tonumber(number))
  end
  return name.validate(value)
end

return name
