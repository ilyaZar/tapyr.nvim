local backend = require("shiny.backend")
local golem = require("shiny.rgolem.backend")
local python = require("shiny.backends.python")
local rnvim = require("shiny.rgolem.rnvim")

local fixtures = vim.fs.joinpath(vim.fn.getcwd(), "tests", "fixtures")
local python_root = vim.fs.joinpath(fixtures, "sample-project")
local golem_root = vim.fs.joinpath(fixtures, "golem-project")

local python_app = assert(backend.detect(python_root), "Python project was not detected")
assert(python_app.backend == "python", "Python backend identity changed")
assert(python_app.id == "python:" .. python_app.entrypoint, "Python app ID is not namespaced")
local python_override = vim.deepcopy(python_app)
python_override.commands = {
  run = { "python", "serve.py" },
  test = { "python", "-m", "pytest" },
}
local python_run = assert(python.task(python_override, "run", { port = 8122 }))
assert(vim.deep_equal(python_run.cmd, python_override.commands.run), "Python run override changed")
assert(python_run.env.SHINY_PORT == "8122", "Python override did not receive SHINY_PORT")
assert(python_run.env.PYTHONDONTWRITEBYTECODE == "1", "Python override writes bytecode")
local python_test = assert(python.task(python_override, "test", {}))
assert(python_test.env.SHINY_PORT == nil, "Python test received a run port")

local golem_app =
  assert(backend.detect(vim.fs.joinpath(golem_root, "R")), "Golem project was not detected")
assert(golem_app.backend == "golem", "Golem backend identity changed")
assert(golem_app.name == "fixtureGolem", "Golem package name was not read")
assert(golem_app.id == "golem:" .. golem_app.root, "Golem app ID is not namespaced")

require("shiny").setup()
vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(golem_root, "R", "run_app.R")))
local mappings = {}
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  mappings[mapping.desc] = mapping.lhs
end
assert(mappings["Shiny: run app"] == "<C-B>", "Golem lost the shared run mapping")
assert(mappings["Shiny: test"] == "<C-T>", "Golem lost the shared test mapping")
assert(mappings["Shiny: document and reload"] == "<C-G>", "Golem document mapping was not attached")
assert(
  mappings["Shiny: run Golem dev script"] == "<C-S-G>",
  "Golem run-dev mapping was not attached"
)

local terminal = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(terminal, "term://" .. golem_root .. "//123:zsh")
local terminal_app = require("shiny.project").find(terminal)
assert(terminal_app and terminal_app.id == golem_app.id, "terminal-buffer detection failed")
vim.api.nvim_buf_delete(terminal, { force = true })

local original_exepath = vim.fn.exepath
vim.fn.exepath = function(command)
  if command == "Rscript" then
    return "/usr/bin/Rscript"
  end
  return original_exepath(command)
end

local run_spec = assert(golem.task(golem_app, "run", { port = 8123 }))
assert(run_spec.cmd[1] == "/usr/bin/Rscript", "Golem run did not use Rscript")
assert(run_spec.env.SHINY_PORT == "8123", "Golem run lost its managed port")
assert(run_spec.cwd == golem_root, "Golem run used the wrong package root")
assert(run_spec.cmd[3]:find("pkgload::load_all", 1, true), "Golem run omitted package loading")
assert(run_spec.cmd[3]:find("shiny::runApp", 1, true), "Golem run omitted Shiny launch")
assert(run_spec.cmd[3]:find('Sys.unsetenv("SHINY_PORT")', 1, true), "Golem run kept server env")
assert(
  not run_spec.cmd[3]:find(golem_root, 1, true),
  "Golem run interpolated the project path into R source"
)

local test_spec = assert(golem.task(golem_app, "test", {}))
assert(test_spec.cmd[3] == 'testthat::test_local(".")', "Golem test command changed")

local override = vim.deepcopy(golem_app)
override.commands = {
  run = { "Rscript", "dev/run_dev.R" },
  test = { "Rscript", "tests/testthat.R" },
}
run_spec = assert(golem.task(override, "run", { port = 8124 }))
assert(
  vim.deep_equal(run_spec.cmd, override.commands.run),
  "Golem run override was not preserved as argv"
)
assert(run_spec.env.SHINY_PORT == "8124", "Golem override did not receive SHINY_PORT")
test_spec = assert(golem.task(override, "test", {}))
assert(vim.deep_equal(test_spec.cmd, override.commands.test), "Golem test override was ignored")

local original_sender = package.loaded["r.send"]
local original_preload = package.preload["r.send"]
local expression
package.loaded["r.send"] = {
  cmd = function(value)
    expression = value
  end,
}
assert(rnvim.send("document_reload", golem_app), "R.nvim document action failed")
assert(expression == "golem::document_and_reload()", "wrong R.nvim expression was sent")
assert(rnvim.send("run_dev", golem_app), "R.nvim run-dev action failed")
assert(expression == "golem::run_dev()", "run-dev expression changed")

local chained = false
local opts = {
  hook = {
    on_filetype = function()
      chained = true
    end,
  },
}
rnvim.chain(opts)
local original_attach = require("shiny").attach
require("shiny").attach = function() end
opts.hook.on_filetype()
require("shiny").attach = original_attach
assert(chained, "R.nvim hook chaining clobbered the previous hook")

local messages = require("shiny.messages")
local original_show = messages.show
local warning
messages.show = function(value)
  warning = value
end
package.loaded["r.send"] = nil
package.preload["r.send"] = function()
  error("R.nvim unavailable")
end
assert(not rnvim.send("document_reload", golem_app), "missing R.nvim action succeeded")
assert(warning:find("R.nvim is required", 1, true), "missing R.nvim was not reported")

messages.show = original_show
package.loaded["r.send"] = original_sender
package.preload["r.send"] = original_preload
vim.fn.exepath = original_exepath

assert(python.detect(golem_root) == nil, "Golem package was accepted as Python")
