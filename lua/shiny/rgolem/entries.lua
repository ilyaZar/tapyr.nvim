local entries = {}

local project = require("shiny.project")
local pattern = "^golex(%d+)$"

---@param shelf string
---@return string[]
function entries.scan(shelf)
  shelf = project.canonical(shelf)
  vim.fn.mkdir(shelf, "p")
  local found = {}
  local handle = vim.uv.fs_scandir(shelf)
  if handle then
    while true do
      local name, kind = vim.uv.fs_scandir_next(handle)
      if not name then
        break
      end
      if kind == "directory" then
        found[#found + 1] = name
      end
    end
  end
  table.sort(found)
  return found
end

---@param shelf string
---@return integer
function entries.next_number(shelf)
  local highest = 0
  for _, name in ipairs(entries.scan(shelf)) do
    local number = name:match(pattern)
    if number then
      highest = math.max(highest, tonumber(number))
    end
  end
  return highest + 1
end

---@param shelf string
---@param name string
---@return string?, string?
function entries.path(shelf, name)
  if
    type(name) ~= "string"
    or name == ""
    or name == "."
    or name == ".."
    or name:find("/", 1, true)
    or name:find("\\", 1, true)
    or name:find("\0", 1, true)
  then
    return nil, "Entry is not a direct child name"
  end

  shelf = project.canonical(shelf)
  local path = project.canonical(vim.fs.joinpath(shelf, name))
  if vim.fs.dirname(path) ~= shelf then
    return nil, "Entry escaped its selected shelf"
  end
  return path
end

---@param shelf string
---@param name string
---@return boolean
function entries.exists(shelf, name)
  local path = entries.path(shelf, name)
  return path ~= nil and vim.fn.isdirectory(path) == 1
end

---@param shelf string
---@param name string
---@return boolean, string?
function entries.delete(shelf, name)
  local path, error_message = entries.path(shelf, name)
  if not path then
    return false, error_message
  end
  if vim.fn.isdirectory(path) ~= 1 then
    return false, "Golex app no longer exists: " .. name
  end
  if vim.fn.delete(path, "rf") ~= 0 then
    return false, "Could not delete Golex app: " .. path
  end
  return true
end

return entries
