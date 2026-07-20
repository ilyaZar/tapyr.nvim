local create = {}

local dialog = require("shiny.dialog")
local messages = require("shiny.messages")
local project = require("shiny.project")

local function path(value)
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(value), ":p"))
end

local function github(source)
  local repository = source:match("^[%w_.-]+/[%w_.-]+$")
  if repository then
    return repository, "https://github.com/" .. repository .. ".git"
  end
  repository = source:match("^https://github%.com/([^/]+/[^/]+)")
    or source:match("^git@github%.com:([^/]+/[^/]+)")
  if repository then
    return repository:gsub("%.git$", ""), source
  end
end

local function provider(template)
  local count = (template.source and 1 or 0)
    + (template.command and 1 or 0)
    + (template.create and 1 or 0)
  if count ~= 1 then
    return nil
  end
  return template.source and "source" or template.command and "command" or "create"
end

---@param source string
---@param destination string
---@return string[]?
function create.command(source, destination)
  local local_source = path(source)
  if vim.fn.isdirectory(local_source) == 1 then
    return { "cp", "-R", local_source .. "/.", destination }
  end

  local _, clone_source = github(source)
  if clone_source then
    return { "git", "clone", "--depth=1", clone_source, destination }
  end
end

local function available_destination(destination)
  destination = path(destination)
  if vim.uv.fs_stat(destination) then
    messages.show("Destination already exists: " .. destination, vim.log.levels.ERROR)
    return nil
  end
  return destination
end

local function execute(command, destination)
  vim.fn.mkdir(vim.fs.dirname(destination), "p")
  vim.system(command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local detail = (result.stderr or ""):match("[^\n]+") or "command failed"
        messages.show("Could not create app: " .. detail, vim.log.levels.ERROR)
        return
      end

      messages.show("Created app at " .. destination)
      local app = vim.fs.joinpath(destination, "app.py")
      if vim.fn.filereadable(app) == 1 then
        vim.cmd.edit(vim.fn.fnameescape(app))
      end
    end)
  end)
  return true
end

---@param source string
---@param destination string
---@return boolean
function create.run(source, destination)
  destination = available_destination(destination)
  if not destination then
    return false
  end

  local command = create.command(source, destination)
  if not command then
    messages.show("Template must be a local directory or GitHub repository", vim.log.levels.ERROR)
    return false
  end
  return execute(command, destination)
end

---@param template ShinyCreationTemplate
---@return string, string, string?
function create.describe(template)
  local kind = provider(template)
  if kind == "source" then
    local repo = github(template.source)
    if repo then
      return "repository", repo, "https://github.com/" .. repo
    end
    return "directory", vim.fn.fnamemodify(vim.fn.expand(template.source), ":~"), nil
  end
  if kind == "command" then
    return "command", template.description or table.concat(template.command, " "), nil
  end
  if kind == "create" then
    return "hook", template.description or "Lua function", nil
  end
  return "invalid", "-", nil
end

local function command(template, destination)
  local has_destination = false
  for _, argument in ipairs(template.command) do
    has_destination = has_destination or argument:find("{destination}", 1, true) ~= nil
  end
  if not has_destination then
    messages.show("Template command must contain {destination}", vim.log.levels.ERROR)
    return false
  end

  destination = available_destination(destination)
  if not destination then
    return false
  end
  local argv = {}
  for _, argument in ipairs(template.command) do
    argument = argument:gsub("{destination}", function()
      return destination
    end)
    argv[#argv + 1] = argument
  end
  return execute(argv, destination)
end

local function run_template(template, destination)
  local kind = provider(template)
  if kind == "source" then
    return create.run(template.source, destination)
  end
  if kind == "command" then
    return command(template, destination)
  end
  if kind == "create" then
    return template.create(destination)
  end
  messages.show("Template requires a source, command, or create hook", vim.log.levels.ERROR)
  return false
end

local function prompt_destination(template, on_confirm)
  vim.ui.input({
    prompt = "New " .. template.name .. " app destination: ",
    default = project.canonical(vim.uv.cwd()) .. "/",
    completion = "dir",
  }, function(destination)
    if not destination or destination == "" then
      return
    end
    local started = run_template(template, destination)
    if started and on_confirm then
      on_confirm()
    end
  end)
end

---@param parent? integer
---@param on_confirm? fun()
function create.prompt(parent, on_confirm)
  local choices = {}
  for _, template in ipairs(require("shiny").config.creation_templates) do
    local provider_name, description, url = create.describe(template)
    if provider_name ~= "invalid" and (not template.available or template.available()) then
      choices[#choices + 1] = {
        label = template.name .. " (" .. description .. ")",
        value = template,
        url = url,
      }
    end
  end
  if #choices == 0 then
    messages.show("No app creation templates are available", vim.log.levels.WARN)
    return
  end
  dialog.menu(parent, "New Shiny app", choices, function(template)
    if template then
      prompt_destination(template, on_confirm)
    end
  end)
end

return create
