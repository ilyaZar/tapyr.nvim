---@mod tapyr Shiny for Python tools for Neovim

local tapyr = {}

local active_app = nil

---@class TapyrMappings
---@field run? string|false
---@field restart? string|false
---@field test? string|false
---@field panel? string|false

---@class TapyrOptions
---@field mappings? TapyrMappings
---@field settings_path? string
---@field template_path_new_app? string

local defaults = {
  settings_path = nil,
  template_path_new_app = "https://github.com/Appsilon/tapyr-template.git",
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

local function find_app(bufnr)
  local app = require("tapyr.project").find(bufnr)
  return app and require("tapyr.registry").resolve(app) or nil
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
    active_app = find_app(bufnr) or active_app
    return
  end

  local app = find_app(bufnr)
  if not app then
    return
  end

  active_app = app
  vim.b[bufnr].tapyr_attached = true

  map(bufnr, tapyr.config.mappings.run, function()
    require("tapyr.tasks").run(app)
  end, "Tapyr: run app")

  map(bufnr, tapyr.config.mappings.restart, function()
    require("tapyr.tasks").restart(app)
  end, "Tapyr: restart app")

  map(bufnr, tapyr.config.mappings.test, function()
    require("tapyr.tasks").test(app)
  end, "Tapyr: test")

  map(bufnr, tapyr.config.mappings.panel, function()
    tapyr.open(app)
  end, "Tapyr: panel")
end

---@param app? TapyrAppDefinition
function tapyr.open(app)
  app = app or find_app(0) or active_app
  local root = app and app.root or vim.uv.cwd()
  root = require("tapyr.registry").context(root)

  return require("tapyr.panel").open(root, app)
end

return tapyr
