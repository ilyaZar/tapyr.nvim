local create = {}

local messages = require("tapyr.messages")

local function path(value)
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(value), ":p"))
end

---@param source string
---@param destination string
---@return string[]?
function create.command(source, destination)
  local local_source = path(source)
  if vim.fn.isdirectory(local_source) == 1 then
    return { "cp", "-R", local_source .. "/.", destination }
  end

  if source:match("^[%w_.-]+/[%w_.-]+$") then
    source = "https://github.com/" .. source .. ".git"
  end
  if source:match("^https://github%.com/") or source:match("^git@github%.com:") then
    return { "git", "clone", "--depth=1", source, destination }
  end
end

---@param source string
---@param destination string
---@return boolean
function create.run(source, destination)
  destination = path(destination)
  if vim.uv.fs_stat(destination) then
    messages.show("Destination already exists: " .. destination, vim.log.levels.ERROR)
    return false
  end

  local command = create.command(source, destination)
  if not command then
    messages.show("Template must be a local directory or GitHub repository", vim.log.levels.ERROR)
    return false
  end

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

---@param root string
---@param on_confirm? fun()
function create.prompt(root, on_confirm)
  vim.ui.input({
    prompt = "New app destination: ",
    default = vim.fs.dirname(root) .. "/",
  }, function(destination)
    if not destination or destination == "" then
      return
    end
    if create.run(require("tapyr").config.template_path_new_app, destination) and on_confirm then
      on_confirm()
    end
  end)
end

return create
