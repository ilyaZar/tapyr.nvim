local registry = {}

local backend = require("shiny.backend")
local project = require("shiny.project")

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
    for _, action in ipairs({ "run", "test" }) do
      local command = entry[action]
      if command ~= nil then
        if type(command) ~= "table" or not vim.islist(command) or vim.tbl_isempty(command) then
          return {}, label .. " has an invalid " .. action .. " command"
        end
        for _, argument in ipairs(command) do
          if type(argument) ~= "string" or argument == "" then
            return {}, label .. " has an invalid " .. action .. " command"
          end
        end
      end
    end

    local root = absolute_path(entry.path, base)
    if vim.fn.isdirectory(root) ~= 1 then
      return {}, root .. " does not exist"
    end
    local app = backend.detect(root)
    if not app or app.root ~= root then
      return {}, root .. " is not a supported Shiny project"
    end
    app.name = entry.name or app.name
    app.port = entry.port
    app.commands = {
      run = entry.run and vim.deepcopy(entry.run) or nil,
      test = entry.test and vim.deepcopy(entry.test) or nil,
    }
    definitions[#definitions + 1] = app
  end

  return definitions
end

local function workspace_manifest(root)
  return project.find_file(root, ".shiny.json")
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
---@param current_app? ShinyAppDefinition
---@param global_path? string
---@return ShinyAppDefinition[], string[]
function registry.load(root, current_app, global_path)
  global_path = global_path or vim.fs.joinpath(vim.fn.stdpath("config"), "shiny.json")

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
  paths[#paths + 1] = global_path

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

---@param app ShinyAppDefinition
---@param global_path? string
---@return ShinyAppDefinition
function registry.resolve(app, global_path)
  local definitions = registry.load(app.root, app, global_path)
  for _, definition in ipairs(definitions) do
    if definition.id == app.id then
      return definition
    end
  end
  return app
end

return registry
