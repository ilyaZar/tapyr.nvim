local registry = {}

local project = require("tapyr.project")

local function absolute_path(path, base)
  path = vim.fn.expand(path)
  if not vim.startswith(path, "/") then
    path = vim.fs.joinpath(base, path)
  end
  return project.canonical(path)
end

local function read_manifest(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
  if not ok or type(decoded) ~= "table" then
    return nil, "Could not read " .. path
  end
  if decoded.version ~= 1 or type(decoded.apps) ~= "table" then
    return nil, "Expected version 1 and an apps list in " .. path
  end

  return decoded
end

local function manifest_apps(path)
  local manifest, error_message = read_manifest(path)
  if not manifest then
    return {}, error_message
  end

  local definitions = {}
  local base = vim.fs.dirname(path)
  for index, entry in ipairs(manifest.apps) do
    local label = path .. " app " .. index
    if type(entry) ~= "table" or type(entry.path) ~= "string" then
      return {}, label .. " needs a path"
    end
    if entry.name ~= nil and type(entry.name) ~= "string" then
      return {}, label .. " has an invalid name"
    end
    if
      entry.port ~= nil
      and (
        type(entry.port) ~= "number"
        or entry.port % 1 ~= 0
        or entry.port < 1
        or entry.port > 65535
      )
    then
      return {}, label .. " has an invalid port"
    end

    local root = absolute_path(entry.path, base)
    local app = project.new(root, {
      name = entry.name,
      port = entry.port,
    })
    if vim.fn.isdirectory(app.root) ~= 1 then
      return {}, app.root .. " does not exist"
    end
    if not project.is_app(app.entrypoint) then
      return {}, app.entrypoint .. " is not a Shiny app"
    end
    definitions[#definitions + 1] = app
  end

  return definitions
end

local function workspace_manifest(root)
  return project.find_file(root, ".tapyr.json")
end

---@param root string
---@return string
function registry.context(root)
  root = project.canonical(root)
  local manifest = workspace_manifest(root)
  return manifest and vim.fs.dirname(manifest) or root
end

local function add(definitions, seen, app)
  definitions[#definitions + 1] = app
  seen[app.id] = true
end

---@param root string
---@param current_app? TapyrAppDefinition
---@param global_path? string
---@return TapyrAppDefinition[], string[]
function registry.load(root, current_app, global_path)
  global_path = global_path or vim.fs.joinpath(vim.fn.stdpath("config"), "tapyr.json")

  local local_manifest = workspace_manifest(root)
  if local_manifest then
    local_manifest = project.canonical(local_manifest)
  end

  local definitions = {}
  local seen = {}
  local notes = {}
  local paths = {}
  if local_manifest then
    paths[#paths + 1] = local_manifest
  end
  if global_path then
    paths[#paths + 1] = global_path
  end

  for _, path in ipairs(paths) do
    local manifest_definitions, note = manifest_apps(path)
    if note then
      notes[#notes + 1] = note
    end
    for _, app in ipairs(manifest_definitions) do
      if not seen[app.id] then
        add(definitions, seen, app)
      end
    end
  end

  if current_app and not seen[current_app.id] then
    add(definitions, seen, current_app)
  end

  return definitions, notes
end

return registry
