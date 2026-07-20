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
  local name = require("shiny.rgolem.name")
  local shelves = require("shiny.rgolem.shelves")
  local package_name, error_message = name.resolve(input)
  if not package_name then
    require("shiny.messages").show(error_message, vim.log.levels.WARN)
    return false
  end

  local shelf = shelves.active()
  if not entries.exists(shelf, package_name) then
    return require("shiny.rgolem.create").at(shelf, package_name)
  end

  local path
  path, error_message = entries.path(shelf, package_name)
  if not path then
    require("shiny.messages").show(error_message, vim.log.levels.ERROR)
    return false
  end
  require("shiny.dialog").confirm(
    nil,
    "Delete " .. path .. " recursively and recreate it?",
    function(confirmed)
      if confirmed then
        require("shiny.rgolem.create").at(shelf, package_name, true)
      end
    end
  )
  return true
end

return rgolem
