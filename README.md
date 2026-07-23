<h1 align="center">shiny.nvim</h1>

<p align="center">
  <a href="https://github.com/ilyaZar/shiny.nvim/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/ilyaZar/shiny.nvim/ci.yml?branch=main&style=flat-square&logo=github&logoColor=white&label=CI&labelColor=2a7e3b&color=1b5e2a"></a>
  <a href="https://codecov.io/gh/ilyaZar/shiny.nvim"><img src="https://img.shields.io/codecov/c/github/ilyaZar/shiny.nvim/main?style=flat-square&logo=codecov&logoColor=white&labelColor=6b3fa0&color=4b2d73"></a>
  <a href="https://github.com/ilyaZar/shiny.nvim/releases"><img src="https://img.shields.io/github/v/release/ilyaZar/shiny.nvim?style=flat-square&label=version&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xIDcuNzc1VjIuNzVDMSAxLjc4NCAxLjc4NCAxIDIuNzUgMWg1LjAyNWMuNDY0IDAgLjkxLjE4NCAxLjIzOC41MTNsNi4yNSA2LjI1YTEuNzUgMS43NSAwIDAgMSAwIDIuNDc0bC01LjAyNiA1LjAyNmExLjc1IDEuNzUgMCAwIDEtMi40NzQgMGwtNi4yNS02LjI1QTEuNzUyIDEuNzUyIDAgMCAxIDEgNy43NzVabTEuNSAwYzAgLjA2Ni4wMjYuMTMuMDczLjE3N2w2LjI1IDYuMjVhLjI1LjI1IDAgMCAwIC4zNTQgMGw1LjAyNS01LjAyNWEuMjUuMjUgMCAwIDAgMC0uMzU0bC02LjI1LTYuMjVhLjI1LjI1IDAgMCAwLS4xNzctLjA3M0gyLjc1YS4yNS4yNSAwIDAgMC0uMjUuMjVaTTYgNWExIDEgMCAxIDEgMCAyIDEgMSAwIDAgMSAwLTJaIi8+PC9zdmc+&labelColor=4a999d&color=346c6e"></a>
  <a href="https://neovim.io"><img src="https://img.shields.io/badge/Neovim-0.11+-3C92D2?style=flat-square&logo=neovim&logoColor=white&labelColor=57A143"></a>
  <a href="https://www.lua.org"><img src="https://img.shields.io/badge/Lua-LuaJIT-343476?style=flat-square&logo=lua&logoColor=white&labelColor=4c4c9d"></a>
  <a href="https://github.com/ilyaZar/shiny.nvim/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ilyaZar/shiny.nvim?style=flat-square&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik04Ljc1Ljc1VjJoLjk4NWMuMzA0IDAgLjYwMy4wOC44NjcuMjMxbDEuMjkuNzM2Yy4wMzguMDIyLjA4LjAzMy4xMjQuMDMzaDIuMjM0YS43NS43NSAwIDAgMSAwIDEuNWgtLjQyN2wyLjExMSA0LjY5MmEuNzUuNzUgMCAwIDEtLjE1NC44MzhsLS41My0uNTMuNTI5LjUzMS0uMDAxLjAwMi0uMDAyLjAwMi0uMDA2LjAwNi0uMDA2LjAwNS0uMDEuMDEtLjA0NS4wNGMtLjIxLjE3Ni0uNDQxLjMyNy0uNjg2LjQ1QzE0LjU1NiAxMC43OCAxMy44OCAxMSAxMyAxMWE0LjQ5OCA0LjQ5OCAwIDAgMS0yLjAyMy0uNDU0IDMuNTQ0IDMuNTQ0IDAgMCAxLS42ODYtLjQ1bC0uMDQ1LS4wNC0uMDE2LS4wMTUtLjAwNi0uMDA2LS4wMDQtLjAwNHYtLjAwMWEuNzUuNzUgMCAwIDEtLjE1NC0uODM4TDEyLjE3OCA0LjVoLS4xNjJjLS4zMDUgMC0uNjA0LS4wNzktLjg2OC0uMjMxbC0xLjI5LS43MzZhLjI0NS4yNDUgMCAwIDAtLjEyNC0uMDMzSDguNzVWMTNoMi41YS43NS43NSAwIDAgMSAwIDEuNWgtNi41YS43NS43NSAwIDAgMSAwLTEuNWgyLjVWMy41aC0uOTg0YS4yNDUuMjQ1IDAgMCAwLS4xMjQuMDMzbC0xLjI4OS43MzdjLS4yNjUuMTUtLjU2NC4yMy0uODY5LjIzaC0uMTYybDIuMTEyIDQuNjkyYS43NS43NSAwIDAgMS0uMTU0LjgzOGwtLjUzLS41My41MjkuNTMxLS4wMDEuMDAyLS4wMDIuMDAyLS4wMDYuMDA2LS4wMTYuMDE1LS4wNDUuMDRjLS4yMS4xNzYtLjQ0MS4zMjctLjY4Ni40NUM0LjU1NiAxMC43OCAzLjg4IDExIDMgMTFhNC40OTggNC40OTggMCAwIDEtMi4wMjMtLjQ1NCAzLjU0NCAzLjU0NCAwIDAgMS0uNjg2LS40NWwtLjA0NS0uMDQtLjAxNi0uMDE1LS4wMDYtLjAwNi0uMDA0LS4wMDR2LS4wMDFhLjc1Ljc1IDAgMCAxLS4xNTQtLjgzOEwyLjE3OCA0LjVIMS43NWEuNzUuNzUgMCAwIDEgMC0xLjVoMi4yMzRhLjI0OS4yNDkgMCAwIDAgLjEyNS0uMDMzbDEuMjg4LS43MzdjLjI2NS0uMTUuNTY0LS4yMy44NjktLjIzaC45ODRWLjc1YS43NS43NSAwIDAgMSAxLjUgMFptMi45NDUgOC40NzdjLjI4NS4xMzUuNzE4LjI3MyAxLjMwNS4yNzNzMS4wMi0uMTM4IDEuMzA1LS4yNzNMMTMgNi4zMjdabS0xMCAwYy4yODUuMTM1LjcxOC4yNzMgMS4zMDUuMjczczEuMDItLjEzOCAxLjMwNS0uMjczTDMgNi4zMjdaIi8+PC9zdmc+&labelColor=629944&color=446a30"></a>
</p>

<p align="center">
Unified Neovim workflow for Shiny for Python and golem apps.
</p>

`shiny.nvim` is a Neovim workflow for Shiny for Python applications and
golem-based R Shiny packages. It detects either project type, runs applications
and tests through Overseer, assigns managed ports, and presents their lifecycle
in one panel.

The panel also contains Golex: a scratch-project manager for creating and
opening disposable golem applications across persistent shelf directories.

## Supported projects

- Shiny for Python projects with an `app.py` that imports `shiny`
- golem packages with `DESCRIPTION` and `inst/golem-config.yml`

Ordinary R Shiny projects that are not golem packages are not detected.

## Requirements

Shared:

- Neovim 0.11 or newer
- [overseer.nvim](https://github.com/stevearc/overseer.nvim)

For Shiny for Python:

- `shiny` and `pytest` in an ancestor `.venv/bin` or Neovim's `PATH`
- optionally `uv` and an ancestor `uv.lock` for first-run `uv sync`
- optionally Linux `/proc` and `ss` to discover apps started outside Neovim

For golem and Golex:

- `Rscript`
- the R packages `golem`, `pkgload`, `shiny`, and `testthat`
- optionally [R.nvim](https://github.com/R-nvim/R.nvim) for
  `document_and_reload()` and `run_dev()`

Python users do not need R, R.nvim, or any R package.

## Installation

With lazy.nvim:

```lua
{
  "ilyaZar/shiny.nvim",
  name = "shiny.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
  opts = {},
}
```

For a local checkout:

```lua
{
  name = "shiny.nvim",
  dir = vim.fn.expand("~/path/to/shiny.nvim"),
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

Shiny initializes automatically. Its defaults can be changed through `opts`:

```lua
{
  "ilyaZar/shiny.nvim",
  name = "shiny.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
  opts = {
    settings_path = vim.fn.stdpath("config") .. "/lua/plugins/shiny.lua",
    mappings = {
      run = "<C-b>",
      restart = "<C-S-b>",
      test = "<C-t>",
      panel = "<leader>tm",
      document_reload = "<C-g>",
      run_dev = "<C-S-g>",
    },
    golex = {
      dir = "/tmp/golskels",
      shelves_path =
        vim.fs.joinpath(vim.fn.stdpath("data"), "shiny", "golex.json"),
      open_cmd = { "nvim" },
    },
  },
}
```

Set an individual mapping to `false` to disable it. The two Golem mappings are
attached only inside a detected golem package.

`creation_templates` is an ordered Lua list used by both the Apps `[N]` chooser
and the Settings tab. The defaults are `Tapyr`, cloned from
`Appsilon/tapyr-template`, and `golem`, created through
`golem::create_golem()`. The latter is offered only when the `{golem}` package
is installed.

A custom entry may use a GitHub repository or local directory as `source`, an
argv-based `command` containing `{destination}`, or a Lua `create` hook:

```lua
local golem = require("shiny.rgolem.create")

creation_templates = {
  {
    name = "Tapyr",
    source = "https://github.com/Appsilon/tapyr-template.git",
  },
  {
    name = "golem",
    create = golem.path,
    available = golem.available,
    description = "golem::create_golem()",
  },
  { name = "local", source = "~/templates/shiny" },
  {
    name = "script",
    command = { "create-shiny", "--output", "{destination}" },
  },
}
```

Providing this list replaces the defaults, so its order is also the chooser
order. Commands are argv arrays and are never passed through a shell.

`golex.open_cmd` is an argv array. `{ "nvim" }` uses `xdg-terminal-exec`,
Ghostty, or Alacritty on Linux. GUI launchers such as `{ "code" }`,
`{ "positron" }`, and `{ "rstudio" }` receive the selected project path
directly. RStudio prefers an `.Rproj`, then `DESCRIPTION`, then
`dev/01_start.R`.

To preserve another R.nvim companion's hook, chain Shiny through the R.nvim
options table:

```lua
{
  "R-nvim/R.nvim",
  opts = function(_, opts)
    require("shiny").setup_rnvim(opts)
  end,
}
```

The hook is optional because managed Golem lifecycle tasks use `Rscript`.

## Usage

The canonical command is `:Shiny`:

- `:Shiny` opens the Apps tab
- `:Shiny panel VIEW` opens `apps`, `golex`, `settings`, or `help`
- `:Shiny golex` opens the native Golex tab
- `:Shiny golex 7` creates `golex07`
- `:Shiny golex my.app` creates `my.app`
- `:Shiny golex next` creates the next numbered Golex app
- `:Shiny action document-reload` sends `golem::document_and_reload()` through
  R.nvim
- `:Shiny action run-dev` sends `golem::run_dev()` through R.nvim

The `run-dev` action executes the project-owned development script. It is
separate from the managed run and restart lifecycle.

Detected project buffers receive:

- `Ctrl+b` to run
- `Ctrl+Shift+b` to restart
- `Ctrl+t` to test
- `<leader>tm` to open the panel
- `Ctrl+g` to document and reload a Golem package through R.nvim
- `Ctrl+Shift+g` to run a Golem dev script through R.nvim

## Panel

`Tab` and `Shift+Tab` cycle Apps, Golex, Settings, and Help. `j`, `k`, the arrow
keys, `gg`, and `G` move between selectable rows. `q` or `Esc` closes the panel.

Every tab uses the same bracketed footer syntax, but only its visible actions
are active:

- Apps: app details, restart, stop, browser, refresh, app template, close
- Golex: create/open, delete, shelves, edit Golex app name, close
- Settings: edit setting, close
- Help: open link, close

Apps shows backend, state, assigned port, process details when available, launch
command, and project. `Enter` opens backend-aware details.

Apps `[N]` first chooses an available creation template, then asks for the full
destination path. The path starts in Neovim's current working directory. Tapyr
clones its GitHub template; golem validates the final directory name as an R
package name before calling `golem::create_golem()`.

Settings has separate Mappings and Creation templates sections. Selecting a
row opens its field in `settings_path` when that readable Lua file is
configured. Shiny never creates or overwrites the settings file.

## Golex

The Golex tab keeps an input row above the selectable projects. Press `N` or
`i` to edit it. An empty row starts with the next numbered name; an existing
draft is preserved. `Esc` returns to normal mode without discarding the draft.
Invalid `Enter` submissions keep the editor open for correction. Typing happens
in an isolated one-line input, so the rest of the panel cannot be edited.
Custom names follow R's package-name rule: at least two characters, an ASCII
letter first, only ASCII letters, digits, or dots, no spaces, and no trailing
dot.

On a project row:

- `Enter` opens the Open/Recreate dialog
- `d` asks before recursively deleting that project

Press `S` for shelves. Shelf selection appears first, followed by a separate
Add new shelf section. `Enter` selects a shelf, and `d` asks before recursively
deleting the selected shelf directory and every project below it. The
configured default shelf cannot be deleted.

Golex apps and shelves are intentionally disposable. Deletion removes their
directories, not only their registry entries. Every destructive prompt names the
complete recursive effect, and deletion is bounded to the selected canonical
entry.

Creation calls `golem::create_golem()` asynchronously. The destination is an
`Rscript` argument and is never interpolated into R source.

## Lifecycle

Python runs:

```text
shiny run --reload --port PORT app.py
```

Python tests run `pytest`. If `shiny` is missing and an ancestor `uv.lock`
exists, one shared `uv sync` task prepares that project before retrying.

Golem runs a package loaded with `pkgload::load_all()`, then passes `run_app()`
to `shiny::runApp()` with the assigned `SHINY_PORT`. This bypasses
`dev/run_dev.R`, whose project-owned behavior may select another port or perform
unrelated preparation. Golem tests run `testthat::test_local(".")`.

Managed applications have one Overseer task per backend-qualified app ID.
Overseer metadata is authoritative for their backend, port, and running state.
Ports are assigned from 8000 through 8199 unless the registry reserves one.
Shiny reports collisions and never stops an unrelated listener.

Linux `ss` and `/proc` discovery supplements managed state for external Shiny
for Python commands. It is not required for plugin-started applications.

## Registries and overrides

Shiny reads `stdpath("config")/shiny.json` and the nearest `.shiny.json`.
Workspace entries appear first and replace matching global entries.

```json
{
  "version": 1,
  "apps": [
    {
      "name": "Python dashboard",
      "path": "apps/dashboard",
      "port": 8012
    },
    {
      "name": "Golem dashboard",
      "path": "packages/dashboard",
      "run": ["Rscript", "dev/run_dev.R"],
      "test": ["Rscript", "tests/testthat.R"]
    }
  ]
}
```

Paths may be absolute or relative to the registry. Shiny detects the backend
from the target directory. `run` and `test` overrides must be non-empty argv
arrays. Run overrides receive `SHINY_PORT`; they must honor it for accurate port
tracking and browser URLs.

## Health and development

Run `:checkhealth shiny` for shared, Python, Golem, Golex, and optional R.nvim
capabilities.

Run the headless suite:

```bash
./scripts/test
```

Generate coverage:

```bash
./scripts/coverage
```

This unified implementation incorporates work from Tapyr.nvim and Rgolem.nvim.
Both copyright notices are preserved in [LICENSE](LICENSE).
