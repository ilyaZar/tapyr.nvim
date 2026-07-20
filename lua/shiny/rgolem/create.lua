local create = {}

local entries = require("shiny.rgolem.entries")
local messages = require("shiny.messages")
local name = require("shiny.rgolem.name")
local project = require("shiny.project")

local expression = table.concat({
  "args <- commandArgs(trailingOnly = TRUE)",
  "golem::create_golem(args[[1]], open = FALSE)",
}, "\n")

---@param path string
---@return string[]?
function create.command(path)
  local rscript = vim.fn.exepath("Rscript")
  if not rscript or rscript == "" then
    return nil
  end
  return { rscript, "--vanilla", "-e", expression, path }
end

---@return boolean
function create.available()
  local rscript = vim.fn.exepath("Rscript")
  if not rscript or rscript == "" then
    return false
  end
  local result = vim
    .system({
      rscript,
      "--vanilla",
      "-e",
      'quit(status = if (requireNamespace("golem", quietly = TRUE)) 0 else 1)',
    }, { text = true })
    :wait()
  return result.code == 0
end

local function create_missing(destination, package_name, callback)
  local command = create.command(destination)
  if not command then
    local error_message = "Rscript is required to create a Golem app"
    messages.show(error_message, vim.log.levels.ERROR)
    return false, error_message
  end

  vim.fn.mkdir(vim.fs.dirname(destination), "p")
  messages.show("Creating Golem app " .. package_name)
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        messages.show("Created " .. package_name .. " at " .. destination)
        if callback then
          callback(true, destination)
        end
        return
      end

      local detail = vim.trim(result.stderr or "")
      if detail == "" then
        detail = "Rscript failed"
      end
      messages.show("Could not create " .. package_name .. ": " .. detail, vim.log.levels.ERROR)
      if callback then
        callback(false)
      end
    end)
  end)
  return true
end

---@param destination string
---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function create.path(destination, callback)
  destination = project.canonical(destination)
  local package_name, error_message = name.validate(vim.fs.basename(destination))
  if not package_name then
    messages.show(error_message, vim.log.levels.WARN)
    return false, error_message
  end
  if vim.uv.fs_stat(destination) then
    error_message = "Destination already exists: " .. destination
    messages.show(error_message, vim.log.levels.ERROR)
    return false, error_message
  end
  return create_missing(destination, package_name, callback)
end

---@param shelf string
---@param input string
---@param overwrite? boolean
---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function create.at(shelf, input, overwrite, callback)
  local package_name, error_message = name.resolve(input)
  if not package_name then
    messages.show(error_message, vim.log.levels.WARN)
    return false, error_message
  end

  local path
  path, error_message = entries.path(shelf, package_name)
  if not path then
    messages.show(error_message, vim.log.levels.ERROR)
    return false, error_message
  end
  local existing = vim.uv.fs_stat(path)
  if existing and existing.type ~= "directory" then
    error_message = "Golex destination exists and is not a directory: " .. path
    messages.show(error_message, vim.log.levels.ERROR)
    return false, error_message
  end
  if existing then
    if not overwrite then
      return false, package_name .. " already exists"
    end
    local deleted
    deleted, error_message = entries.delete(shelf, package_name)
    if not deleted then
      messages.show(error_message, vim.log.levels.ERROR)
      return false, error_message
    end
  end
  return create_missing(path, package_name, callback)
end

---@param shelf string
---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function create.next(shelf, callback)
  return create.at(shelf, name.numbered(entries.next_number(shelf)), false, callback)
end

return create
