---@mod shiny Shiny application tools for Neovim

local shiny = {}

local active_app = nil

---@class ShinyMappings
---@field run? string|false
---@field restart? string|false
---@field test? string|false
---@field panel? string|false
---@field document_reload? string|false
---@field run_dev? string|false

---@class ShinyGolexOptions
---@field dir? string
---@field shelves_path? string
---@field open_cmd? string[]

---@class ShinyOptions
---@field mappings? ShinyMappings
---@field settings_path? string
---@field template_path_new_app? string
---@field golex? ShinyGolexOptions

local defaults = {
  settings_path = nil,
  template_path_new_app = "https://github.com/Appsilon/tapyr-template.git",
  mappings = {
    run = "<C-b>",
    restart = "<C-S-b>",
    test = "<C-t>",
    panel = "<leader>tm",
    document_reload = "<C-g>",
    run_dev = "<C-S-g>",
  },
  golex = {},
}

shiny.config = vim.deepcopy(defaults)

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
  local app = require("shiny.project").find(bufnr)
  return app and require("shiny.registry").resolve(app) or nil
end

---@param options? ShinyOptions
function shiny.setup(options)
  shiny.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), options or {})
  require("shiny.rgolem").configure(shiny.config.golex)
end

---@param bufnr? integer
function shiny.attach(bufnr)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end

  if vim.b[bufnr].shiny_attached then
    active_app = find_app(bufnr) or active_app
    return
  end

  local app = find_app(bufnr)
  if not app then
    return
  end

  active_app = app
  vim.b[bufnr].shiny_attached = true

  map(bufnr, shiny.config.mappings.run, function()
    require("shiny.tasks").run(app)
  end, "Shiny: run app")

  map(bufnr, shiny.config.mappings.restart, function()
    require("shiny.tasks").restart(app)
  end, "Shiny: restart app")

  map(bufnr, shiny.config.mappings.test, function()
    require("shiny.tasks").test(app)
  end, "Shiny: test")

  map(bufnr, shiny.config.mappings.panel, function()
    shiny.open(app)
  end, "Shiny: panel")

  if app.backend == "golem" then
    map(bufnr, shiny.config.mappings.document_reload, function()
      require("shiny.rgolem.rnvim").send("document_reload", app)
    end, "Shiny: document and reload")

    map(bufnr, shiny.config.mappings.run_dev, function()
      require("shiny.rgolem.rnvim").send("run_dev", app)
    end, "Shiny: run Golem dev script")
  end
end

---@param app? ShinyAppDefinition
---@param view? string
function shiny.open(app, view)
  app = app or find_app(0) or active_app
  local root = app and app.root or vim.uv.cwd()
  root = require("shiny.registry").context(root)

  return require("shiny.panel").open(root, app, view)
end

---@param opts table
---@return table
function shiny.setup_rnvim(opts)
  return require("shiny.rgolem.rnvim").chain(opts)
end

---@param opts table
function shiny.command(opts)
  local args = opts.fargs or {}
  local function invalid()
    require("shiny.messages").show(
      "Unknown Shiny command: " .. table.concat(args, " "),
      vim.log.levels.ERROR
    )
  end

  if not args[1] then
    shiny.open()
    return
  end

  if args[1] == "panel" then
    local valid_views = {
      apps = true,
      golex = true,
      settings = true,
      help = true,
    }
    if args[3] or (args[2] and not valid_views[args[2]]) then
      invalid()
      return
    end
    shiny.open(nil, args[2])
    return
  end
  if args[1] == "golex" then
    if args[3] then
      invalid()
      return
    end
    if not args[2] then
      shiny.open(nil, "golex")
    elseif args[2] == "next" then
      require("shiny.rgolem").next()
    else
      require("shiny.rgolem").create_or_confirm(args[2])
    end
    return
  end
  if args[1] == "action" then
    local actions = {
      ["document-reload"] = "document_reload",
      ["run-dev"] = "run_dev",
    }
    local action = actions[args[2]]
    if action and not args[3] then
      require("shiny.rgolem.rnvim").send(action)
      return
    end
  end

  invalid()
end

---@param arglead string
---@param command_line string
---@return string[]
function shiny.complete(arglead, command_line)
  local words = vim.split(command_line, "%s+", { trimempty = true })
  local candidates
  local route = words[2]
  local completing_argument = #words > 2 or (route ~= nil and command_line:match("%s$"))
  if completing_argument and route == "panel" then
    candidates = { "apps", "golex", "settings", "help" }
  elseif completing_argument and route == "golex" then
    candidates = { "next" }
  elseif completing_argument and route == "action" then
    candidates = { "document-reload", "run-dev" }
  elseif #words <= 2 then
    candidates = { "panel", "golex", "action" }
  else
    candidates = {}
  end

  return vim.tbl_filter(function(candidate)
    return vim.startswith(candidate, arglead)
  end, candidates)
end

shiny.setup()

return shiny
