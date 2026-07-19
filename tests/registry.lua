local registry = require("tapyr.registry")
local root = vim.fn.tempname()
local workspace = vim.fs.joinpath(root, "workspace")
local local_app = vim.fs.joinpath(workspace, "apps", "local")
local global_app = vim.fs.joinpath(root, "global")
vim.fn.mkdir(local_app, "p")
vim.fn.mkdir(global_app, "p")
vim.fn.writefile({ "from shiny import App" }, vim.fs.joinpath(local_app, "app.py"))
vim.fn.writefile({ "from shiny import App" }, vim.fs.joinpath(global_app, "app.py"))

local global_manifest = vim.fs.joinpath(root, "tapyr.json")
vim.fn.writefile({
  vim.json.encode({
    version = 1,
    apps = {
      {
        name = "global app",
        path = global_app,
        port = 8123,
      },
    },
  }),
}, global_manifest)
vim.fn.writefile({
  vim.json.encode({
    version = 1,
    apps = {
      {
        name = "local app",
        path = "apps/local",
      },
    },
  }),
}, vim.fs.joinpath(workspace, ".tapyr.json"))

assert(registry.context(local_app) == workspace, "workspace context was not detected")
local definitions, notes = registry.load(local_app, nil, global_manifest)
assert(#notes == 0, "valid registries produced a warning")
assert(#definitions == 2, "global and workspace registries were not combined")
assert(definitions[1].name == "local app", "workspace app was not listed first")
assert(definitions[2].name == "global app", "global app order changed")
assert(definitions[2].port == 8123, "configured port was lost")
assert(definitions[2].entrypoint == vim.fs.joinpath(global_app, "app.py"), "entrypoint changed")

local current = require("tapyr.project").new(vim.fs.joinpath(root, "current"))
definitions = registry.load(local_app, current, global_manifest)
assert(#definitions == 3, "current app was not included")
assert(definitions[3].id == current.id, "current app identity changed")

vim.fn.writefile({ "{not json" }, global_manifest)
definitions, notes = registry.load(local_app, nil, global_manifest)
assert(#definitions == 1, "valid workspace registry was lost after a global error")
assert(#notes == 1, "invalid global registry warning was lost")

vim.fn.delete(root, "rf")
