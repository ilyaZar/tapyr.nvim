local health = {}

function health.check()
  local root = (vim.uv or vim.loop).cwd()

  vim.health.start("tapyr.nvim")

  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim 0.10 or newer")
  else
    vim.health.error("Neovim 0.10 or newer is required")
  end

  for _, name in ipairs({ "run", "test" }) do
    local command = require("tapyr.tasks").resolve(name, root)
    if command then
      vim.health.ok(vim.fs.basename(command[1]) .. " is available")
    else
      local executable = name == "run" and "shiny" or "pytest"
      vim.health.error(executable .. " is not available in .venv or Neovim's PATH")
    end
  end

  if vim.fn.executable("ss") == 1 then
    vim.health.ok("ss is available")
  else
    vim.health.error("ss is required to list local apps")
  end

  if vim.fn.isdirectory("/proc") == 1 then
    vim.health.ok("/proc is available")
  else
    vim.health.error("/proc is required to read app details")
  end

  if pcall(require, "overseer") then
    vim.health.ok("overseer.nvim is available")
  else
    vim.health.error("overseer.nvim is required for app and test tasks")
  end
end

return health
