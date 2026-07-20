local backend = {}

local providers = {
  (require("shiny.backends.python")),
  (require("shiny.rgolem.backend")),
}
local by_id = {}
for _, provider in ipairs(providers) do
  by_id[provider.id] = provider
end

---@param id string
---@return table?
function backend.get(id)
  return by_id[id]
end

---@param start string
---@param bufnr? integer
---@return ShinyAppDefinition?
function backend.detect(start, bufnr)
  for index = #providers, 1, -1 do
    local app = providers[index].detect(start, bufnr)
    if app then
      return app
    end
  end
end

---@return table[]
function backend.all()
  return providers
end

return backend
