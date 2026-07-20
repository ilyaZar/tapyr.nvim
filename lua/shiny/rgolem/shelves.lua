local shelves = {}

local project = require("shiny.project")
local state = {
  items = {},
  active = 1,
}

local function default_dir()
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    return vim.fs.joinpath(vim.fn.stdpath("cache"), "golskels")
  end
  return "/tmp/golskels"
end

local function save()
  if not state.path then
    return
  end
  vim.fn.mkdir(vim.fs.dirname(state.path), "p")
  vim.fn.writefile({
    vim.json.encode({
      shelves = state.items,
      active = state.active,
    }),
  }, state.path)
end

local function load()
  state.items = { state.default }
  state.active = 1
  if vim.fn.filereadable(state.path) ~= 1 then
    return
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(state.path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return
  end

  local seen = { [state.default] = true }
  for _, path in ipairs(type(decoded.shelves) == "table" and decoded.shelves or {}) do
    if type(path) == "string" and path ~= "" then
      path = project.canonical(path)
      if not seen[path] then
        seen[path] = true
        state.items[#state.items + 1] = path
      end
    end
  end

  if type(decoded.active) == "number" then
    state.active = math.max(1, math.min(math.floor(decoded.active), #state.items))
  end
end

---@param options? ShinyGolexOptions
function shelves.configure(options)
  options = options or {}
  state.default = project.canonical(options.dir or default_dir())
  state.path = project.canonical(
    options.shelves_path or vim.fs.joinpath(vim.fn.stdpath("data"), "shiny", "golex.json")
  )
  load()
end

---@return string
function shelves.active()
  return state.items[state.active]
end

---@return string[]
function shelves.all()
  return vim.deepcopy(state.items)
end

---@return integer
function shelves.active_index()
  return state.active
end

---@param path string
---@return integer
function shelves.add(path)
  path = project.canonical(path)
  for index, item in ipairs(state.items) do
    if item == path then
      state.active = index
      save()
      return index
    end
  end

  state.items[#state.items + 1] = path
  state.active = #state.items
  save()
  return state.active
end

---@param index integer
---@return boolean
function shelves.select(index)
  if not state.items[index] then
    return false
  end
  state.active = index
  save()
  return true
end

---@param index integer
---@return boolean, string?
function shelves.delete(index)
  local path = state.items[index]
  if not path then
    return false, "Shelf no longer exists in the registry"
  end
  if index == 1 or path == state.default then
    return false, "The default shelf cannot be deleted"
  end
  if project.canonical(path) ~= path then
    return false, "Shelf path changed; refresh before deleting"
  end
  if vim.uv.fs_stat(path) and vim.fn.delete(path, "rf") ~= 0 then
    return false, "Could not delete shelf directory: " .. path
  end

  table.remove(state.items, index)
  if state.active == index then
    state.active = 1
  elseif state.active > index then
    state.active = state.active - 1
  end
  save()
  return true
end

return shelves
