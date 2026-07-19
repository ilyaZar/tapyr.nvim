<h1 align="center">tapyr.nvim</h1>

<p align="center">
  <a href="https://github.com/ilyaZar/tapyr.nvim/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/ilyaZar/tapyr.nvim/ci.yml?branch=main&style=flat-square&logo=github&logoColor=white&label=CI&labelColor=2a7e3b&color=1b5e2a"></a>
  <a href="https://codecov.io/gh/ilyaZar/tapyr.nvim"><img src="https://img.shields.io/codecov/c/github/ilyaZar/tapyr.nvim/main?style=flat-square&logo=codecov&logoColor=white&labelColor=6b3fa0&color=4b2d73"></a>
  <a href="https://github.com/ilyaZar/tapyr.nvim/releases"><img src="https://img.shields.io/github/v/release/ilyaZar/tapyr.nvim?style=flat-square&label=version&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xIDcuNzc1VjIuNzVDMSAxLjc4NCAxLjc4NCAxIDIuNzUgMWg1LjAyNWMuNDY0IDAgLjkxLjE4NCAxLjIzOC41MTNsNi4yNSA2LjI1YTEuNzUgMS43NSAwIDAgMSAwIDIuNDc0bC01LjAyNiA1LjAyNmExLjc1IDEuNzUgMCAwIDEtMi40NzQgMGwtNi4yNS02LjI1QTEuNzUyIDEuNzUyIDAgMCAxIDEgNy43NzVabTEuNSAwYzAgLjA2Ni4wMjYuMTMuMDczLjE3N2w2LjI1IDYuMjVhLjI1LjI1IDAgMCAwIC4zNTQgMGw1LjAyNS01LjAyNWEuMjUuMjUgMCAwIDAgMC0uMzU0bC02LjI1LTYuMjVhLjI1LjI1IDAgMCAwLS4xNzctLjA3M0gyLjc1YS4yNS4yNSAwIDAgMC0uMjUuMjVaTTYgNWExIDEgMCAxIDEgMCAyIDEgMSAwIDAgMSAwLTJaIi8+PC9zdmc+&labelColor=4a999d&color=346c6e"></a>
  <a href="https://neovim.io"><img src="https://img.shields.io/badge/Neovim-0.11+-3C92D2?style=flat-square&logo=neovim&logoColor=white&labelColor=57A143"></a>
  <a href="https://www.lua.org"><img src="https://img.shields.io/badge/Lua-LuaJIT-343476?style=flat-square&logo=lua&logoColor=white&labelColor=4c4c9d"></a>
  <a href="https://github.com/ilyaZar/tapyr.nvim/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ilyaZar/tapyr.nvim?style=flat-square&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxNiAxNiI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik04Ljc1Ljc1VjJoLjk4NWMuMzA0IDAgLjYwMy4wOC44NjcuMjMxbDEuMjkuNzM2Yy4wMzguMDIyLjA4LjAzMy4xMjQuMDMzaDIuMjM0YS43NS43NSAwIDAgMSAwIDEuNWgtLjQyN2wyLjExMSA0LjY5MmEuNzUuNzUgMCAwIDEtLjE1NC44MzhsLS41My0uNTMuNTI5LjUzMS0uMDAxLjAwMi0uMDAyLjAwMi0uMDA2LjAwNi0uMDA2LjAwNS0uMDEuMDEtLjA0NS4wNGMtLjIxLjE3Ni0uNDQxLjMyNy0uNjg2LjQ1QzE0LjU1NiAxMC43OCAxMy44OCAxMSAxMyAxMWE0LjQ5OCA0LjQ5OCAwIDAgMS0yLjAyMy0uNDU0IDMuNTQ0IDMuNTQ0IDAgMCAxLS42ODYtLjQ1bC0uMDQ1LS4wNC0uMDE2LS4wMTUtLjAwNi0uMDA2LS4wMDQtLjAwNHYtLjAwMWEuNzUuNzUgMCAwIDEtLjE1NC0uODM4TDEyLjE3OCA0LjVoLS4xNjJjLS4zMDUgMC0uNjA0LS4wNzktLjg2OC0uMjMxbC0xLjI5LS43MzZhLjI0NS4yNDUgMCAwIDAtLjEyNC0uMDMzSDguNzVWMTNoMi41YS43NS43NSAwIDAgMSAwIDEuNWgtNi41YS43NS43NSAwIDAgMSAwLTEuNWgyLjVWMy41aC0uOTg0YS4yNDUuMjQ1IDAgMCAwLS4xMjQuMDMzbC0xLjI4OS43MzdjLS4yNjUuMTUtLjU2NC4yMy0uODY5LjIzaC0uMTYybDIuMTEyIDQuNjkyYS43NS43NSAwIDAgMS0uMTU0LjgzOGwtLjUzLS41My41MjkuNTMxLS4wMDEuMDAyLS4wMDIuMDAyLS4wMDYuMDA2LS4wMTYuMDE1LS4wNDUuMDRjLS4yMS4xNzYtLjQ0MS4zMjctLjY4Ni40NUM0LjU1NiAxMC43OCAzLjg4IDExIDMgMTFhNC40OTggNC40OTggMCAwIDEtMi4wMjMtLjQ1NCAzLjU0NCAzLjU0NCAwIDAgMS0uNjg2LS40NWwtLjA0NS0uMDQtLjAxNi0uMDE1LS4wMDYtLjAwNi0uMDA0LS4wMDR2LS4wMDFhLjc1Ljc1IDAgMCAxLS4xNTQtLjgzOEwyLjE3OCA0LjVIMS43NWEuNzUuNzUgMCAwIDEgMC0xLjVoMi4yMzRhLjI0OS4yNDkgMCAwIDAgLjEyNS0uMDMzbDEuMjg4LS43MzdjLjI2NS0uMTUuNTY0LS4yMy44NjktLjIzaC45ODRWLjc1YS43NS43NSAwIDAgMSAxLjUgMFptMi45NDUgOC40NzdjLjI4NS4xMzUuNzE4LjI3MyAxLjMwNS4yNzNzMS4wMi0uMTM4IDEuMzA1LS4yNzNMMTMgNi4zMjdabS0xMCAwYy4yODUuMTM1LjcxOC4yNzMgMS4zMDUuMjczczEuMDItLjEzOCAxLjMwNS0uMjczTDMgNi4zMjdaIi8+PC9zdmc+&labelColor=629944&color=446a30"></a>
</p>

<p align="center">
Minimal Neovim workflow for Shiny for Python apps.
</p>

The `tapyr.nvim` plugin provides several QoL enhancements that help
[Shiny for Python](https://shiny.posit.co/py/) development inside Neovim. It
finds projects from an `app.py` import, runs apps and tests through Overseer,
and shows local apps in a small floating panel.

The panel can also track several apps from one workspace or from unrelated
directories. Apps started through Tapyr receive their own Overseer task, output
buffer, and local port.

It works with regular Shiny projects, including Appsilon's
[Tapyr template](https://www.appsilon.com/rhinoverse/tapyr). See the Tapyr
[documentation](https://appsilon.github.io/tapyr-docs/) and
[template repository](https://github.com/Appsilon/tapyr-template).

## Requirements

- Neovim 0.11 or newer
- Linux with `/proc` and `ss`
- [`overseer.nvim`](https://github.com/stevearc/overseer.nvim)
- A prepared project environment with `shiny` and `pytest` in `.venv/bin` or
  Neovim's `PATH`

## Installation

With lazy.nvim:

```lua
{
  "ilyaZar/tapyr.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

For a local development checkout:

```lua
{
  name = "tapyr.nvim",
  dir = vim.fn.expand("~/path/to/tapyr.nvim"),
  dependencies = {
    "stevearc/overseer.nvim",
  },
}
```

Tapyr initializes automatically and requires no configuration call.

## Usage

Open a file below a Shiny `app.py`. Tapyr adds these buffer-local mappings:

- `Ctrl+b` runs the app
- `Ctrl+Shift+b` restarts the app task
- `Ctrl+t` runs the test suite
- `<leader>tm` opens the panel

These are familiar IDE-style defaults. Change or disable any of them with
`opts`:

```lua
{
  "ilyaZar/tapyr.nvim",
  dependencies = {
    "stevearc/overseer.nvim",
  },
  opts = {
    template_path_new_app = "https://github.com/Appsilon/tapyr-template.git",
    mappings = {
      run = "<C-b>",
      restart = "<C-S-b>",
      test = "<C-t>",
      panel = "<leader>tm",
    },
  },
}
```

Set an individual mapping to `false` to disable it.

`:Tapyr` opens the panel directly.

Inside the panel:

- `Tab` and `Shift+Tab` cycle views
- `n` creates an app from the configured template
- `r` refreshes the app list
- `R` starts or restarts the selected app
- `x` stops the selected app
- `o` opens the selected app
- `Enter` opens files from the Project view
- `q` or `Esc` closes the panel

Run `:checkhealth tapyr` to verify external dependencies.

Tapyr selects the running task in Overseer without overriding its configured
task-list layout or output strategy.

## Tracked apps

Tapyr reads an optional global registry from
`stdpath("config")/tapyr.json` and an optional `.tapyr.json` found above the
current app. Both files use the same format:

```json
{
  "version": 1,
  "apps": [
    {
      "name": "Admin",
      "path": "apps/admin"
    },
    {
      "name": "Reporting",
      "path": "~/projects/reporting",
      "port": 8012
    }
  ]
}
```

Relative paths are resolved from the registry file. Each path must identify a
directory containing a Shiny `app.py`. An app may reserve a fixed `port`.
Workspace entries appear first and replace matching global entries. The current
app and untracked Shiny processes remain visible without a registry.

## New apps

Press `n` in the panel and enter a destination to create an app from the
configured template. The default is Appsilon's
[Tapyr template](https://github.com/Appsilon/tapyr-template). Set
`template_path_new_app` to another GitHub repository, `owner/repository`, or a
local directory to use a different template.

Tapyr uses a shallow clone for GitHub repositories or copies a local template.
It refuses an existing destination and does not install packages or prepare a
Python environment.

## Project conventions

Tapyr runs `shiny run --reload --port <port> app.py` and `pytest`. It searches
the app and its parent directories for `.venv/bin`, then uses Neovim's `PATH`.
Project detection expects an `app.py` that imports `shiny`.

Configured ports are used as written. Otherwise, Tapyr assigns the first free
port from 8000 through 8199 and keeps that assignment for the Neovim session.
It reports collisions instead of stopping an unrelated process.

The Apps view lists the public port for each local Shiny command and hides the
internal redirect listener when the public port is known.

Tapyr uses the prepared Python environment without changing its dependencies.

## Development

Run the headless tests:

```bash
./scripts/test
```

Generate the LCOV report after installing `luacov` and `luacov-reporter-lcov`:

```bash
./scripts/coverage
```

The coverage script writes `coverage/lcov.info` and enforces at least 70% line
coverage across the shipped Lua modules.

## License

MIT
