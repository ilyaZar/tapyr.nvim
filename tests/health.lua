local health = require("tapyr.health")

local original_executable = vim.fn.executable
local original_exepath = vim.fn.exepath
local original_has = vim.fn.has
local original_health = vim.health
local original_isdirectory = vim.fn.isdirectory
local original_overseer = package.loaded.overseer
local original_preload = package.preload.overseer

local ok_messages = {}
local error_messages = {}
vim.health = {
  start = function() end,
  ok = function(message)
    ok_messages[#ok_messages + 1] = message
  end,
  error = function(message)
    error_messages[#error_messages + 1] = message
  end,
}

vim.fn.has = function()
  return 1
end
vim.fn.executable = function()
  return 1
end
vim.fn.exepath = function(command)
  return "/usr/bin/" .. command
end
vim.fn.isdirectory = function()
  return 1
end
package.loaded.overseer = {}

health.check()
assert(#ok_messages == 6, "healthy environment was not reported")

vim.fn.has = function()
  return 0
end
vim.fn.executable = function()
  return 0
end
vim.fn.exepath = function()
  return ""
end
vim.fn.isdirectory = function()
  return 0
end
package.loaded.overseer = nil
package.preload.overseer = function()
  error("overseer unavailable")
end

health.check()
assert(#error_messages == 6, "missing dependencies were not reported")

vim.fn.executable = original_executable
vim.fn.exepath = original_exepath
vim.fn.has = original_has
vim.fn.isdirectory = original_isdirectory
vim.health = original_health
package.loaded.overseer = original_overseer
package.preload.overseer = original_preload
