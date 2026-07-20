local rnvim = {}

local messages = require("shiny.messages")

---@param action "document_reload"|"run_dev"
---@param app? ShinyAppDefinition
---@return boolean
function rnvim.send(action, app)
  app = app or require("shiny.project").find(0)
  if not app or app.backend ~= "golem" then
    messages.show("Current buffer is not in a Golem project", vim.log.levels.WARN)
    return false
  end

  local definition = require("shiny.rgolem.backend").actions[action]
  if not definition then
    messages.show("Unknown Golem action: " .. tostring(action), vim.log.levels.ERROR)
    return false
  end

  local ok, sender = pcall(require, "r.send")
  if not ok or type(sender.cmd) ~= "function" then
    messages.show("R.nvim is required for " .. definition.description, vim.log.levels.ERROR)
    return false
  end
  sender.cmd(definition.expression)
  return true
end

---@param opts table
---@return table
function rnvim.chain(opts)
  opts = opts or {}
  opts.hook = opts.hook or {}
  local previous = opts.hook.on_filetype
  opts.hook.on_filetype = function(...)
    if previous then
      previous(...)
    end
    require("shiny").attach(vim.api.nvim_get_current_buf())
  end
  return opts
end

return rnvim
