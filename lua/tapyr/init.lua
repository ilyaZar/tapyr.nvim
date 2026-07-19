---@mod tapyr Shiny for Python tools for Neovim

local tapyr = {}

local active_root = nil

---@class TapyrMappings
---@field run? string|false
---@field restart? string|false
---@field test? string|false
---@field panel? string|false

---@class TapyrOptions
---@field mappings? TapyrMappings

local defaults = {
  mappings = {
    run = "<C-b>",
    restart = "<C-S-b>",
    test = "<C-t>",
    panel = "<leader>tm",
  },
}

tapyr.config = vim.deepcopy(defaults)

local function map(bufnr, lhs, callback, desc)
  if not lhs then
    return
  end

  vim.keymap.set("n", lhs, callback, {
    buffer = bufnr,
    desc = desc,
    silent = true,
  })
end

---@param options? TapyrOptions
function tapyr.setup(options)
  tapyr.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), options or {})
end

---@param bufnr? integer
function tapyr.attach(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end

  if vim.b[bufnr].tapyr_attached then
    active_root = vim.b[bufnr].tapyr_root
    return
  end

  local root = require("tapyr.project").find_root(bufnr)
  if not root then
    return
  end

  active_root = root
  vim.b[bufnr].tapyr_attached = true
  vim.b[bufnr].tapyr_root = root

  map(bufnr, tapyr.config.mappings.run, function()
    require("tapyr.tasks").run(root)
  end, "Tapyr: run app")

  map(bufnr, tapyr.config.mappings.restart, function()
    require("tapyr.tasks").restart(root)
  end, "Tapyr: restart app")

  map(bufnr, tapyr.config.mappings.test, function()
    require("tapyr.tasks").test(root)
  end, "Tapyr: test")

  map(bufnr, tapyr.config.mappings.panel, function()
    tapyr.open(root)
  end, "Tapyr: panel")
end

---@param root? string
function tapyr.open(root)
  root = root or require("tapyr.project").find_root(0) or active_root or vim.uv.cwd()

  return require("tapyr.panel").open(root)
end

return tapyr
