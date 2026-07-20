local messages = {}

---@param message string
---@param level? integer
function messages.show(message, level)
  vim.notify(message, level or vim.log.levels.INFO, {
    title = "Shiny",
  })
end

return messages
