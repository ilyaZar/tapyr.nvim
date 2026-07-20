local golem = {
  id = "golem",
  label = "Golem",
}

local project = require("shiny.project")

local run_expression = table.concat({
  'port <- as.integer(Sys.getenv("SHINY_PORT"))',
  'Sys.unsetenv("SHINY_PORT")',
  'pkgload::load_all(".", quiet = TRUE)',
  "shiny::runApp(",
  "  run_app(),",
  "  port = port,",
  "  launch.browser = FALSE",
  ")",
}, "\n")

local function package_name(root)
  local description = vim.fs.joinpath(root, "DESCRIPTION")
  for _, line in ipairs(vim.fn.readfile(description, "", 100)) do
    local name = line:match("^Package:%s*(%S+)")
    if name then
      return name
    end
  end
  return vim.fs.basename(root)
end

---@param start string
---@return ShinyAppDefinition?
function golem.detect(start)
  local description = project.find_file(start, "DESCRIPTION")
  if not description then
    return nil
  end

  local root = vim.fs.dirname(description)
  local config = vim.fs.joinpath(root, "inst", "golem-config.yml")
  if vim.fn.filereadable(config) ~= 1 then
    return nil
  end

  return project.definition("golem", root, root, {
    name = package_name(root),
  })
end

---@param app ShinyAppDefinition
---@param action "run"|"test"
---@param context table
---@return table?, string?
function golem.task(app, action, context)
  if action == "run" and not context.port then
    return nil, "A port is required to run " .. app.name
  end

  local command = app.commands and app.commands[action]
  if command then
    return {
      cmd = vim.deepcopy(command),
      cwd = app.root,
      env = action == "run" and { SHINY_PORT = tostring(context.port) } or {},
    }
  end

  local rscript = vim.fn.exepath("Rscript")
  if not rscript or rscript == "" then
    return nil, "Rscript is not available in Neovim's PATH"
  end
  if action == "test" then
    return {
      cmd = { rscript, "-e", 'testthat::test_local(".")' },
      cwd = app.root,
      env = {},
    }
  end
  return {
    cmd = { rscript, "-e", run_expression },
    cwd = app.root,
    env = { SHINY_PORT = tostring(context.port) },
  }
end

---@param action "run"|"test"
---@return string
function golem.describe(action)
  if action == "run" then
    return "Rscript: pkgload + shiny::runApp on <auto> port"
  end
  return "Rscript: testthat::test_local"
end

golem.actions = {
  document_reload = {
    expression = "golem::document_and_reload()",
    description = "document and reload through R.nvim",
  },
  run_dev = {
    expression = "golem::run_dev()",
    description = "run project dev script through R.nvim",
  },
}

---@return table[]
function golem.health()
  local rscript = vim.fn.exepath("Rscript")
  local checks = {
    {
      ok = rscript ~= "",
      success = "Rscript is available",
      failure = "Rscript is unavailable; Golem lifecycle and Golex are disabled",
    },
  }

  if rscript ~= "" then
    local result = vim
      .system({
        rscript,
        "--vanilla",
        "-e",
        table.concat({
          'packages <- c("golem", "pkgload", "shiny", "testthat")',
          "missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]",
          'cat(paste(missing, collapse = ", "))',
          "quit(status = length(missing))",
        }, "\n"),
      }, { text = true })
      :wait()
    local missing = vim.trim(result.stdout or "")
    checks[#checks + 1] = {
      ok = result.code == 0,
      success = "Required Golem R packages are available",
      failure = missing == "" and "Required Golem R packages are unavailable"
        or "Missing R packages: " .. missing,
    }
  end

  local ok = pcall(require, "r.send")
  checks[#checks + 1] = {
    ok = ok,
    success = "R.nvim actions are available",
    failure = "R.nvim is unavailable; managed Rscript lifecycle still works",
  }
  return checks
end

return golem
