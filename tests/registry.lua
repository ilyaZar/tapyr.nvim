local backend = require("shiny.backend")
local registry = require("shiny.registry")
local root = vim.fn.tempname()
local workspace = vim.fs.joinpath(root, "workspace")
local local_app = vim.fs.joinpath(workspace, "apps", "local")
local global_app = vim.fs.joinpath(root, "global")
vim.fn.mkdir(local_app, "p")
vim.fn.mkdir(global_app, "p")
vim.fn.writefile({ "from shiny import App" }, vim.fs.joinpath(local_app, "app.py"))
vim.fn.writefile({ "from shiny import App" }, vim.fs.joinpath(global_app, "app.py"))

local global_manifest = vim.fs.joinpath(root, "shiny.json")
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
}, vim.fs.joinpath(workspace, ".shiny.json"))

assert(registry.context(local_app) == workspace, "workspace context was not detected")
local definitions, notes = registry.load(local_app, nil, global_manifest)
assert(#notes == 0, "valid registries produced a warning")
assert(#definitions == 2, "global and workspace registries were not combined")
assert(definitions[1].name == "local app", "workspace app was not listed first")
assert(definitions[2].name == "global app", "global app order changed")
assert(definitions[2].port == 8123, "configured port was lost")
assert(definitions[2].entrypoint == vim.fs.joinpath(global_app, "app.py"), "entrypoint changed")

local resolved = registry.resolve(assert(backend.detect(global_app)), global_manifest)
assert(resolved.name == "global app", "registry name was not applied to a detected app")
assert(resolved.port == 8123, "registry port was not applied to a detected app")

local golem_root = vim.fs.joinpath(root, "golem")
vim.fn.mkdir(vim.fs.joinpath(golem_root, "inst"), "p")
vim.fn.writefile({ "Package: registryGolem" }, vim.fs.joinpath(golem_root, "DESCRIPTION"))
vim.fn.writefile({}, vim.fs.joinpath(golem_root, "inst", "golem-config.yml"))
local golem_manifest = vim.fs.joinpath(root, "golem.json")
vim.fn.writefile({
  vim.json.encode({
    version = 1,
    apps = {
      {
        path = golem_root,
        port = 8124,
        run = { "Rscript", "dev/run_dev.R" },
        test = { "Rscript", "tests/testthat.R" },
      },
    },
  }),
}, golem_manifest)
local golem_definitions, golem_notes = registry.load(golem_root, nil, golem_manifest)
assert(#golem_notes == 0, "valid Golem registry produced a warning")
assert(#golem_definitions == 1, "Golem registry entry was not loaded")
assert(golem_definitions[1].backend == "golem", "Golem registry lost its backend")
assert(golem_definitions[1].port == 8124, "Golem registry lost its port")
assert(
  vim.deep_equal(golem_definitions[1].commands.run, { "Rscript", "dev/run_dev.R" }),
  "Golem run override was not preserved"
)

local current_root = vim.fs.joinpath(root, "current")
vim.fn.mkdir(current_root, "p")
vim.fn.writefile({ "from shiny import App" }, vim.fs.joinpath(current_root, "app.py"))
local current = assert(backend.detect(current_root))
definitions = registry.load(local_app, current, global_manifest)
assert(#definitions == 3, "current app was not included")
assert(definitions[3].id == current.id, "current app identity changed")

vim.fn.writefile({ "{not json" }, global_manifest)
definitions, notes = registry.load(local_app, nil, global_manifest)
assert(#definitions == 1, "valid workspace registry was lost after a global error")
assert(#notes == 1, "invalid global registry warning was lost")

vim.fn.delete(root, "rf")
