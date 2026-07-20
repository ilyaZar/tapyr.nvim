local rgolem = {}

---@param options? ShinyGolexOptions
function rgolem.configure(options)
  require("shiny.rgolem.shelves").configure(options)
  require("shiny.rgolem.launch").configure(options)
end

---@param callback? fun(ok: boolean, path?: string)
---@return boolean, string?
function rgolem.next(callback)
  local shelf = require("shiny.rgolem.shelves").active()
  return require("shiny.rgolem.create").next(shelf, callback)
end

---@param input string
---@return boolean
function rgolem.create_or_confirm(input)
  local entries = require("shiny.rgolem.entries")
  local shelves = require("shiny.rgolem.shelves")
  local name, error_message = entries.resolve(input)
  if not name then
    require("shiny.messages").show(error_message, vim.log.levels.WARN)
    return false
  end

  local shelf = shelves.active()
  if not entries.exists(shelf, name) then
    return require("shiny.rgolem.create").at(shelf, name)
  end

  local path
  path, error_message = entries.path(shelf, name)
  if not path then
    require("shiny.messages").show(error_message, vim.log.levels.ERROR)
    return false
  end
  require("shiny.dialog").confirm(
    nil,
    "Delete " .. path .. " recursively and recreate it?",
    function(confirmed)
      if confirmed then
        require("shiny.rgolem.create").at(shelf, name, true)
      end
    end
  )
  return true
end

return rgolem
