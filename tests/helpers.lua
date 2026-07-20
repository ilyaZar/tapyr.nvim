local helpers = {}

function helpers.rendered_footer(win)
  win = win or vim.api.nvim_get_current_win()
  local parts = {}
  local configured = vim.api.nvim_win_get_config(win).footer
  if type(configured) == "table" then
    for _, part in ipairs(configured) do
      parts[#parts + 1] = part[1]
    end
  end
  for _, candidate in ipairs(vim.api.nvim_list_wins()) do
    if
      candidate ~= win
      and vim.bo[vim.api.nvim_win_get_buf(candidate)].filetype == "shiny-footer"
      and vim.api.nvim_win_get_config(candidate).win == win
    then
      vim.list_extend(
        parts,
        vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(candidate), 0, -1, false)
      )
    end
  end
  return table.concat(parts)
end

return helpers
