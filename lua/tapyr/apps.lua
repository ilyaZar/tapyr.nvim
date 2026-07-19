local apps = {}

local tasks = require("tapyr.tasks")
local messages = require("tapyr.messages")

---@class TapyrApp
---@field host string
---@field port integer
---@field pid? integer
---@field argv? string[]
---@field command? string
---@field cwd? string
---@field project? string
---@field start_time string
---@field url string

---@class TapyrProcess
---@field pid integer
---@field argv string[]
---@field command string
---@field cwd? string
---@field start_time? string

local function read_command(pid)
  if not pid then
    return nil, nil
  end

  local handle = io.open("/proc/" .. pid .. "/cmdline", "rb")
  if not handle then
    return nil, nil
  end

  local raw = handle:read("*a")
  handle:close()

  local argv = {}
  for arg in raw:gmatch("([^%z]+)") do
    argv[#argv + 1] = arg
  end
  if vim.tbl_isempty(argv) then
    return nil, nil
  end

  return argv, table.concat(argv, " ")
end

local function read_working_directory(pid)
  if not pid then
    return nil
  end

  local proc_cwd = "/proc/" .. pid .. "/cwd"
  local cwd = vim.fn.resolve(proc_cwd)
  if cwd == "" or cwd == proc_cwd then
    return nil
  end
  return cwd
end

local function read_start_time(pid)
  local handle = io.open("/proc/" .. pid .. "/stat", "r")
  if not handle then
    return nil
  end

  local stat = handle:read("*a")
  handle:close()

  local fields = stat:match("^%d+ %(.+%) (.+)$")
  if not fields then
    return nil
  end

  local index = 0
  for value in fields:gmatch("%S+") do
    index = index + 1
    if index == 20 then
      return value
    end
  end
end

local function read_parent_pid(pid)
  local handle = io.open("/proc/" .. pid .. "/status", "r")
  if not handle then
    return nil
  end

  for line in handle:lines() do
    local parent = line:match("^PPid:%s+(%d+)")
    if parent then
      handle:close()
      return tonumber(parent)
    end
  end

  handle:close()
end

local function find_project_root(path)
  if not path or path == "" then
    return nil
  end

  local pyproject = vim.fs.find("pyproject.toml", {
    upward = true,
    path = path,
    type = "file",
  })[1]
  if pyproject then
    return vim.fs.dirname(pyproject)
  end
end

local function parse_address(address)
  local host, port = address:match("^%[(.*)%]:(%d+)$")
  if not host then
    host, port = address:match("^(.*):(%d+)$")
  end
  if not host or not port then
    return nil, nil
  end

  host = host:gsub("%%.*$", "")
  return host, tonumber(port)
end

local function is_local_host(host)
  return host == "127.0.0.1"
    or host == "localhost"
    or host == "::1"
    or host == "0.0.0.0"
    or host == "::"
    or host == "*"
end

local function browser_url(host, port)
  local url_host = host
  if url_host == "0.0.0.0" or url_host == "::" or url_host == "*" then
    url_host = "127.0.0.1"
  end
  if url_host == "::1" then
    return "http://[::1]:" .. port
  end
  return "http://" .. url_host .. ":" .. port
end

local function shiny_run_index(argv)
  for index, argument in ipairs(argv or {}) do
    if vim.fs.basename(argument):lower() == "shiny" and argv[index + 1] == "run" then
      return index + 1
    end
  end
end

---@param argv? string[]
---@return boolean
function apps.is_shiny_command(argv)
  return shiny_run_index(argv) ~= nil
end

---@param pid integer
---@return TapyrProcess?
function apps.inspect(pid)
  local argv, command = read_command(pid)
  if not argv then
    return nil
  end

  return {
    pid = pid,
    argv = argv,
    command = command,
    cwd = read_working_directory(pid),
    start_time = read_start_time(pid),
  }
end

local function reload_ports(argv)
  if not argv then
    return nil, nil
  end

  local run_index = shiny_run_index(argv)
  if not run_index then
    return nil, nil
  end

  local reload = false
  local app_port = 8000
  local autoreload_port = 0
  local index = run_index + 1
  while index <= #argv do
    local argument = argv[index]
    if argument == "--reload" or argument == "-r" then
      reload = true
    elseif argument == "--port" or argument == "-p" then
      app_port = tonumber(argv[index + 1]) or app_port
      index = index + 1
    elseif argument == "--autoreload-port" then
      autoreload_port = tonumber(argv[index + 1]) or autoreload_port
      index = index + 1
    else
      app_port = tonumber(argument:match("^%-%-port=(%d+)$"))
        or tonumber(argument:match("^%-p(%d+)$"))
        or app_port
      autoreload_port = tonumber(argument:match("^%-%-autoreload%-port=(%d+)$")) or autoreload_port
    end
    index = index + 1
  end

  if not reload then
    return nil, nil
  end
  return app_port, autoreload_port
end

---@param argv? string[]
---@param port integer
---@return boolean
function apps.is_public_listener(argv, port)
  local app_port, autoreload_port = reload_ports(argv)
  if not app_port then
    return true
  end
  if app_port ~= 0 then
    return port == app_port
  end
  return autoreload_port == 0 or port ~= autoreload_port
end

local function listener_pids(line)
  local pids = {}
  local seen = {}
  for value in line:gmatch("pid=(%d+)") do
    local pid = tonumber(value)
    if pid and not seen[pid] then
      seen[pid] = true
      pids[#pids + 1] = pid
    end
  end
  return pids
end

local function find_shiny_owner(line)
  for _, listener_pid in ipairs(listener_pids(line)) do
    local pid = listener_pid
    for _ = 1, 12 do
      if not pid or pid <= 1 then
        break
      end

      local process = apps.inspect(pid)
      if process and apps.is_shiny_command(process.argv) then
        return process
      end

      pid = read_parent_pid(pid)
    end
  end
end

---@return TapyrApp[], string?
function apps.find()
  if vim.fn.executable("ss") ~= 1 then
    return {}, "Install ss to list local apps"
  end

  local result = vim.system({ "ss", "-H", "-ltnp" }, { text = true }):wait()
  if result.code ~= 0 then
    return {}, "Could not read local apps with ss"
  end

  local found_apps = {}
  local seen = {}

  for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
    local fields = vim.split(line, "%s+")
    local address = fields[4]
    local host, port
    if address then
      host, port = parse_address(address)
    end

    if host and port and is_local_host(host) then
      local process = find_shiny_owner(line)
      if process and process.start_time then
        local project = find_project_root(process.cwd) or process.cwd

        ---@type TapyrApp
        local app = {
          host = host,
          port = port,
          pid = process.pid,
          argv = process.argv,
          command = process.command,
          cwd = process.cwd,
          project = project,
          start_time = process.start_time,
          url = browser_url(host, port),
        }

        local key = table.concat({
          tostring(host),
          tostring(port),
          tostring(process.pid),
        }, ":")

        if not seen[key] and apps.is_public_listener(process.argv, port) then
          seen[key] = true
          found_apps[#found_apps + 1] = app
        end
      end
    end
  end

  table.sort(found_apps, function(a, b)
    if a.port == b.port then
      return tostring(a.pid or "") < tostring(b.pid or "")
    end
    return a.port < b.port
  end)

  return found_apps, nil
end

---@param app? TapyrApp
---@return boolean
function apps.stop(app)
  if not app or not app.pid then
    return false
  end

  local current = apps.inspect(app.pid)
  if
    not current
    or not app.start_time
    or current.start_time ~= app.start_time
    or current.cwd ~= app.cwd
    or not apps.is_shiny_command(current.argv)
  then
    messages.show("App process changed; refresh the panel", vim.log.levels.WARN)
    return false
  end

  local result = vim.system({ "kill", tostring(app.pid) }, { text = true }):wait()
  if result.code ~= 0 then
    messages.show("Could not stop app (PID " .. app.pid .. ")", vim.log.levels.ERROR)
    return false
  end

  messages.show("Stopped app (PID " .. app.pid .. ")")
  return true
end

---@param app? TapyrApp
---@param root string
---@return boolean
function apps.restart(app, root)
  if not app then
    messages.show("Select an app first", vim.log.levels.WARN)
    return false
  end

  local project = app.project or app.cwd
  local is_current_project = project and (project == root or vim.startswith(project, root .. "/"))

  if is_current_project then
    if not apps.stop(app) then
      return false
    end
    vim.defer_fn(function()
      tasks.start(root, false)
    end, 250)
    return true
  end

  if not app.argv or vim.tbl_isempty(app.argv) then
    messages.show("Cannot determine how this app was started", vim.log.levels.WARN)
    return false
  end

  if not apps.stop(app) then
    return false
  end
  vim.defer_fn(function()
    local job = vim.fn.jobstart(app.argv, {
      cwd = app.cwd or app.project,
      detach = true,
    })
    if job <= 0 then
      messages.show("Could not restart " .. (app.command or "app"), vim.log.levels.ERROR)
    else
      messages.show("Restarted " .. (app.command or "app"))
    end
  end, 250)
  return true
end

---@param url string
function apps.open_in_browser(url)
  if vim.ui and vim.ui.open then
    vim.ui.open(url)
    return
  end

  if vim.fn.executable("xdg-open") == 1 then
    vim.fn.jobstart({ "xdg-open", url }, { detach = true })
  else
    messages.show("No browser command is available for " .. url, vim.log.levels.WARN)
  end
end

return apps
