local project = {}

---@param path string
---@return boolean
function project.is_app(path)
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end

  for _, line in ipairs(vim.fn.readfile(path, "", 200)) do
    if
      line:match("^%s*from%s+shiny[%s%.]")
      or line:match("^%s*import%s+shiny%s*$")
      or line:match("^%s*import%s+shiny[%s,]")
    then
      return true
    end
  end

  return false
end

---@class TapyrAppDefinition
---@field id string
---@field name string
---@field root string
---@field entrypoint string
---@field port? integer

---@param path string
---@return string
function project.canonical(path)
  local expanded = vim.fn.expand(path)
  local absolute = vim.fn.fnamemodify(expanded, ":p")
  local normalized = vim.fs.normalize(absolute)
  return vim.uv.fs_realpath(normalized) or normalized
end

---@param root string
---@param options? table
---@return TapyrAppDefinition
function project.new(root, options)
  options = options or {}
  root = project.canonical(root)
  local entrypoint = project.canonical(vim.fs.joinpath(root, "app.py"))

  return {
    id = entrypoint,
    name = options.name or vim.fs.basename(root),
    root = root,
    entrypoint = entrypoint,
    port = options.port,
  }
end

---@param root string
---@param name string
---@return string?
function project.find_file(root, name)
  return vim.fs.find(name, {
    upward = true,
    path = root,
    type = "file",
  })[1]
end

---@param root string
---@return string
function project.root(root)
  local pyproject = project.find_file(root, "pyproject.toml")
  return pyproject and vim.fs.dirname(pyproject) or root
end

---@param root string
---@param name string
---@return string
function project.file(root, name)
  local found = project.find_file(root, name)
  return found or vim.fs.joinpath(root, name)
end

---@param bufnr? integer
---@return TapyrAppDefinition?
function project.find(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  local start = path ~= "" and vim.fs.dirname(path) or vim.uv.cwd()
  local app = project.find_file(start, "app.py")

  if app and project.is_app(app) then
    return project.new(vim.fs.dirname(app))
  end
end

return project
