local tasks = {}

local messages = require("tapyr.messages")
local app_tasks = {}

local tools = {
  run = {
    executable = "shiny",
    arguments = { "run", "--reload", "app.py" },
  },
  test = {
    executable = "pytest",
    arguments = {},
  },
}

local function get_overseer()
  local ok, overseer = pcall(require, "overseer")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return nil
  end
  return overseer
end

local function task_is_gone(task)
  return not task or task:is_disposed()
end

local function show_task(task)
  local overseer = get_overseer()
  if not overseer then
    return
  end
  overseer.open({
    enter = false,
    focus_task_id = task.id,
  })
end

---@param name "run"|"test"
---@param root string
---@return string[]?
function tasks.resolve(name, root)
  local tool = tools[name]
  local project_executable = vim.fs.joinpath(root, ".venv", "bin", tool.executable)
  local executable

  if vim.fn.executable(project_executable) == 1 then
    executable = project_executable
  else
    executable = vim.fn.exepath(tool.executable)
  end

  if not executable or executable == "" then
    return nil
  end

  return vim.list_extend({ executable }, vim.deepcopy(tool.arguments))
end

local function missing_tool(name, root)
  messages.show(
    tools[name].executable
      .. " is not available in "
      .. vim.fs.joinpath(root, ".venv", "bin")
      .. " or Neovim's PATH",
    vim.log.levels.ERROR
  )
end

local function new_app_task(root)
  local command = tasks.resolve("run", root)
  if not command then
    missing_tool("run", root)
    return nil
  end

  local overseer = get_overseer()
  if not overseer then
    return nil
  end

  return overseer.new_task({
    name = "Tapyr: run app",
    cmd = command,
    cwd = root,
    env = { PYTHONDONTWRITEBYTECODE = "1" },
    components = { "default" },
  })
end

---@param name "run"|"test"
---@return string
function tasks.describe(name)
  local tool = tools[name]
  return table.concat(vim.list_extend({ tool.executable }, vim.deepcopy(tool.arguments)), " ")
end

---@param root string
---@param show_task_list? boolean
function tasks.start(root, show_task_list)
  local task = new_app_task(root)
  if not task then
    return
  end

  app_tasks[root] = task
  task:start()
  if show_task_list ~= false then
    show_task(task)
  end
end

---@param root string
function tasks.run(root)
  local task = app_tasks[root]
  if task_is_gone(task) then
    task = new_app_task(root)
    if not task then
      return
    end
    app_tasks[root] = task
  end

  local ok, constants = pcall(require, "overseer.constants")
  if not ok then
    messages.show("Overseer is required to run apps and tests", vim.log.levels.ERROR)
    return
  end

  if task.status == constants.STATUS.PENDING then
    task:start()
  elseif task.status ~= constants.STATUS.RUNNING then
    task:restart(true)
  end

  show_task(task)
end

---@param root string
function tasks.restart(root)
  local task = app_tasks[root]
  if task_is_gone(task) then
    task = new_app_task(root)
    if not task then
      return
    end
    app_tasks[root] = task
    task:start()
  else
    task:restart(true)
  end

  show_task(task)
end

---@param root string
function tasks.test(root)
  local command = tasks.resolve("test", root)
  if not command then
    missing_tool("test", root)
    return
  end

  local overseer = get_overseer()
  if not overseer then
    return
  end

  local task = overseer.new_task({
    name = "Tapyr: test app",
    cmd = command,
    cwd = root,
    env = { PYTHONDONTWRITEBYTECODE = "1" },
    components = {
      { "on_output_quickfix", open_on_match = true, set_diagnostics = true },
      "on_result_diagnostics",
      "default",
    },
  })

  task:start()
  show_task(task)
end

return tasks
