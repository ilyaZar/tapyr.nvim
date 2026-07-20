local project = {}

---@class ShinyAppDefinition
---@field id string
---@field backend "python"|"golem"
---@field name string
---@field root string
---@field entrypoint string
---@field port? integer
---@field commands table<"run"|"test", string[]?>

---@param path string
---@return string
function project.canonical(path)
  local expanded = vim.fn.expand(path)
  local absolute = vim.fn.fnamemodify(expanded, ":p")
  local normalized = vim.fs.normalize(absolute)
  return vim.uv.fs_realpath(normalized) or normalized
end

---@param bufnr? integer
---@return string
function project.start(bufnr)
  bufnr = bufnr or 0
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return vim.uv.cwd()
  end

  local terminal_cwd = path:match("^term://(.-)//%d+:")
  if terminal_cwd then
    return project.canonical(terminal_cwd)
  end
  if vim.fn.isdirectory(path) == 1 then
    return project.canonical(path)
  end
  return project.canonical(vim.fs.dirname(path))
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
function project.python_root(root)
  local pyproject = project.find_file(root, "pyproject.toml")
  return pyproject and vim.fs.dirname(pyproject) or root
end

---@param backend "python"|"golem"
---@param root string
---@param entrypoint string
---@param options? table
---@return ShinyAppDefinition
function project.definition(backend, root, entrypoint, options)
  options = options or {}
  root = project.canonical(root)
  entrypoint = project.canonical(entrypoint)

  return {
    id = backend .. ":" .. (backend == "golem" and root or entrypoint),
    backend = backend,
    name = options.name or vim.fs.basename(root),
    root = root,
    entrypoint = entrypoint,
    port = options.port,
    commands = options.commands or {},
  }
end

---@param bufnr? integer
---@return ShinyAppDefinition?
function project.find(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end
  return require("shiny.backend").detect(project.start(bufnr), bufnr)
end

return project
