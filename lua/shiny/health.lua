local health = {}

local function report(check)
  if check.ok then
    vim.health.ok(check.success)
  else
    vim.health.warn(check.failure)
  end
end

function health.check()
  vim.health.start("shiny.nvim")

  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim 0.11 or newer")
  else
    vim.health.error("Neovim 0.11 or newer is required")
  end

  if pcall(require, "overseer") then
    vim.health.ok("overseer.nvim is available")
  else
    vim.health.error("overseer.nvim is required for app and test tasks")
  end

  for _, provider in ipairs(require("shiny.backend").all()) do
    vim.health.start("shiny.nvim " .. provider.label .. " backend")
    for _, check in ipairs(provider.health()) do
      report(check)
    end
  end
end

return health
