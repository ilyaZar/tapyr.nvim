local adapter = {}

local messages = require("shiny.messages")

---@return table?
function adapter.get()
  local ok, overseer = pcall(require, "overseer")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

---@param spec table
---@return table?
function adapter.new(spec)
  local overseer = adapter.get()
  return overseer and overseer.new_task(spec) or nil
end

---@param task table
function adapter.show(task)
  local overseer = adapter.get()
  if overseer then
    overseer.open({
      enter = false,
      focus_task_id = task.id,
    })
  end
end

return adapter
