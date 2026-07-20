if vim.g.loaded_shiny == 1 then
  return
end
vim.g.loaded_shiny = 1

vim.api.nvim_create_user_command("Shiny", function(opts)
  require("shiny").command(opts)
end, {
  nargs = "*",
  desc = "Open Shiny or run a Shiny subcommand",
  complete = function(arglead, command_line)
    return require("shiny").complete(arglead, command_line)
  end,
  force = false,
})

vim.api.nvim_create_autocmd({ "BufEnter", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("shiny", { clear = true }),
  callback = function(event)
    require("shiny").attach(event.buf)
  end,
})
