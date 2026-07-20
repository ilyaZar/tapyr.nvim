local launch = {}

local messages = require("shiny.messages")
local open_command

---@param options? ShinyGolexOptions
function launch.configure(options)
  open_command = options and options.open_cmd or nil
end

---@param argv string[]
---@param path string
---@return string[]?
local function terminal_command(argv, path)
  local command = vim.deepcopy(argv)
  command[#command + 1] = path
  if vim.fn.executable("xdg-terminal-exec") == 1 then
    return vim.list_extend({ "xdg-terminal-exec" }, command)
  end
  if vim.fn.executable("ghostty") == 1 then
    return vim.list_extend({ "ghostty", "-e" }, command)
  end
  if vim.fn.executable("alacritty") == 1 then
    return vim.list_extend({ "alacritty", "-e" }, command)
  end
end

---@param path string
---@return string
function launch.rstudio_target(path)
  local projects = vim.fn.glob(vim.fs.joinpath(path, "*.Rproj"), false, true)
  if type(projects) == "table" and projects[1] and projects[1] ~= "" then
    return projects[1]
  end
  for _, relative in ipairs({ "DESCRIPTION", "dev/01_start.R" }) do
    local candidate = vim.fs.joinpath(path, relative)
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return path
end

---@param path string
---@return string[]?
function launch.command(path)
  if type(open_command) ~= "table" or vim.tbl_isempty(open_command) then
    return terminal_command({ "nvim" }, path)
  end

  local command = vim.deepcopy(open_command)
  if type(command[1]) ~= "string" or command[1] == "" then
    return nil
  end
  for _, argument in ipairs(command) do
    if type(argument) ~= "string" then
      return nil
    end
  end
  if command[1] == "nvim" then
    return terminal_command(command, path)
  end
  if command[1] == "rstudio" and vim.fn.executable(command[1]) ~= 1 then
    if vim.fn.executable("/usr/lib/rstudio/rstudio") == 1 then
      command[1] = "/usr/lib/rstudio/rstudio"
    end
  end
  if vim.endswith(command[1], "rstudio") then
    path = launch.rstudio_target(path)
  end
  command[#command + 1] = path
  return command
end

---@param path string
---@param label string
---@return boolean
function launch.open(path, label)
  local command = launch.command(path)
  if not command then
    messages.show("No supported terminal launcher found for " .. label, vim.log.levels.ERROR)
    return false
  end

  local job = vim.fn.jobstart(command, { detach = true })
  if job <= 0 then
    messages.show(
      "Could not open " .. label .. " with " .. vim.inspect(command),
      vim.log.levels.ERROR
    )
    return false
  end
  messages.show("Opening " .. label)
  return true
end

return launch
