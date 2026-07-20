local create = require("shiny.rgolem.create")
local entries = require("shiny.rgolem.entries")
local launch = require("shiny.rgolem.launch")
local messages = require("shiny.messages")
local shelves = require("shiny.rgolem.shelves")

local root = vim.fn.tempname()
local default = vim.fs.joinpath(root, "default")
local other = vim.fs.joinpath(root, "other")
local state_path = vim.fs.joinpath(root, "golex.json")
vim.fn.mkdir(default, "p")
vim.fn.mkdir(other, "p")
shelves.configure({
  dir = default,
  shelves_path = state_path,
  open_cmd = { "code" },
})

assert(shelves.active() == default, "configured default shelf was not active")
assert(shelves.add(other) == 2, "new shelf was not appended")
assert(shelves.active() == other, "new shelf was not selected")
shelves.configure({
  dir = default,
  shelves_path = state_path,
})
assert(shelves.active() == other, "active shelf was not persisted")
assert(#shelves.all() == 2, "shelf list was not persisted")

assert(entries.resolve("7") == "golex07", "single-digit Golex name was not padded")
assert(entries.resolve("12") == "golex12", "multi-digit Golex name changed")
assert(entries.resolve("my.app") == "my.app", "valid R package name was rejected")
assert(entries.resolve("../escape") == nil, "path traversal was accepted")
assert(entries.resolve("bad_name") == nil, "invalid R package name was accepted")
assert(entries.resolve(".hidden") == nil, "hidden directory name was accepted")

vim.fn.mkdir(vim.fs.joinpath(other, "golex02"), "p")
vim.fn.mkdir(vim.fs.joinpath(other, "golex01"), "p")
vim.fn.mkdir(vim.fs.joinpath(other, "named"), "p")
assert(
  vim.deep_equal(entries.scan(other), { "golex01", "golex02", "named" }),
  "Golex entries were not sorted"
)
assert(entries.next_number(other) == 3, "next Golex number changed")

local outside = vim.fs.joinpath(root, "outside")
vim.fn.mkdir(outside, "p")
vim.uv.fs_symlink(outside, vim.fs.joinpath(other, "escape"), { dir = true })
assert(entries.path(other, "escape") == nil, "symlink escaped its selected shelf")

local original_exepath = vim.fn.exepath
vim.fn.exepath = function(command)
  if command == "Rscript" then
    return "/usr/bin/Rscript"
  end
  return original_exepath(command)
end
local target = vim.fs.joinpath(other, "newapp")
local command = assert(create.command(target))
assert(command[#command] == target, "Golex path was not passed as an Rscript argument")
assert(
  not table.concat(command, "\n"):match("create_golem%([^)]*" .. vim.pesc(target)),
  "Golex path was interpolated into R source"
)

local original_system = vim.system
local original_show = messages.show
local system_command
local created
messages.show = function() end
vim.system = function(argv, _, callback)
  system_command = argv
  callback({ code = 0, stdout = "", stderr = "" })
end
assert(
  create.at(other, "newapp", false, function(ok, path)
    created = ok and path
  end),
  "valid Golex creation did not start"
)
vim.wait(100, function()
  return created ~= nil
end)
assert(system_command[#system_command] == target, "async creation lost its path argument")
assert(created == target, "successful creation callback lost its target")

local original_executable = vim.fn.executable
vim.fn.executable = function(executable)
  if executable == "xdg-terminal-exec" or executable == "/usr/lib/rstudio/rstudio" then
    return 1
  end
  return original_executable(executable)
end
launch.configure({ open_cmd = { "code", "--reuse-window" } })
assert(
  vim.deep_equal(launch.command(target), { "code", "--reuse-window", target }),
  "GUI editor launcher changed"
)
launch.configure({ open_cmd = { "nvim" } })
assert(
  vim.deep_equal(launch.command(target), { "xdg-terminal-exec", "nvim", target }),
  "Neovim terminal wrapper changed"
)

local rstudio_project = vim.fs.joinpath(other, "rstudio-app")
vim.fn.mkdir(rstudio_project, "p")
local rproj = vim.fs.joinpath(rstudio_project, "app.Rproj")
vim.fn.writefile({}, rproj)
launch.configure({ open_cmd = { "rstudio" } })
local rstudio_command = launch.command(rstudio_project)
assert(vim.endswith(rstudio_command[1], "rstudio"), "RStudio launcher changed")
assert(rstudio_command[2] == rproj, "RStudio did not target the project file")

local disposable = vim.fs.joinpath(other, "disposable")
vim.fn.mkdir(disposable, "p")
assert(entries.delete(other, "disposable"), "bounded entry deletion failed")
assert(vim.fn.isdirectory(disposable) == 0, "entry directory was not deleted")

vim.fn.writefile({ "data" }, vim.fs.joinpath(other, "marker"))
assert(not shelves.delete(1), "default shelf was deleted")
assert(shelves.delete(2), "registered shelf deletion failed")
assert(vim.fn.isdirectory(other) == 0, "shelf directory was not recursively deleted")
assert(#shelves.all() == 1, "deleted shelf remained registered")

vim.system = original_system
vim.fn.executable = original_executable
vim.fn.exepath = original_exepath
messages.show = original_show
vim.fn.delete(root, "rf")
