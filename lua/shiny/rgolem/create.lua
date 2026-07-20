local create = {}

local entries = require("shiny.rgolem.entries")
local messages = require("shiny.messages")

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

---@param shelf string
---@param input string
---@param overwrite? boolean
---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function create.at(shelf, input, overwrite, callback)
  local name, error_message = entries.resolve(input)
  if not name then
    messages.show(error_message, vim.log.levels.WARN)
    return false, error_message
  end

  local path
  path, error_message = entries.path(shelf, name)
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
      return false, name .. " already exists"
    end
    local deleted
    deleted, error_message = entries.delete(shelf, name)
    if not deleted then
      messages.show(error_message, vim.log.levels.ERROR)
      return false, error_message
    end
  end

  local command = create.command(path)
  if not command then
    error_message = "Rscript is required to create a Golex app"
    messages.show(error_message, vim.log.levels.ERROR)
    return false, error_message
  end

  vim.fn.mkdir(shelf, "p")
  messages.show("Creating Golex app " .. name)
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        messages.show("Created " .. name .. " at " .. path)
        if callback then
          callback(true, path)
        end
        return
      end

      local detail = vim.trim(result.stderr or "")
      if detail == "" then
        detail = "Rscript failed"
      end
      messages.show("Could not create " .. name .. ": " .. detail, vim.log.levels.ERROR)
      if callback then
        callback(false)
      end
    end)
  end)
  return true
end

---@param shelf string
---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function create.next(shelf, callback)
  return create.at(shelf, tostring(entries.next_number(shelf)), false, callback)
end

return create
