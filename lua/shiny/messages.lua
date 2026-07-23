local messages = {}

---@param message string
---@param level? integer
---@param timeout? integer
function messages.show(message, level, timeout)
  local options = { title = "Shiny" }
  if timeout then
    options.timeout = timeout
  end
  vim.notify(message, level or vim.log.levels.INFO, options)
end

return messages
