<h1 align="center">tapyr.nvim</h1>

<p align="center">
  <a href="https://github.com/ilyaZar/tapyr.nvim/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/ilyaZar/tapyr.nvim/ci.yml?branch=main&style=flat-square&logo=github&logoColor=white&label=CI&labelColor=2a7e3b&color=1b5e2a"></a>
  <a href="https://codecov.io/gh/ilyaZar/tapyr.nvim"><img src="https://img.shields.io/codecov/c/github/ilyaZar/tapyr.nvim/main?style=flat-square&logo=codecov&logoColor=white&labelColor=6b3fa0&color=4b2d73"></a>
  <a href="https://github.com/ilyaZar/tapyr.nvim/releases"><img src="https://img.shields.io/github/v/release/ilyaZar/tapyr.nvim?style=flat-square&label=version&labelColor=4a999d&color=346c6e"></a>
  <a href="https://neovim.io"><img src="https://img.shields.io/badge/Neovim-0.10+-3f7f52?style=flat-square&logo=neovim&logoColor=white&labelColor=57a143"></a>
  <a href="https://www.lua.org"><img src="https://img.shields.io/badge/Lua-LuaJIT-343476?style=flat-square&logo=lua&logoColor=white&labelColor=4c4c9d"></a>
  <a href="https://www.kernel.org"><img src="https://img.shields.io/badge/Linux-required-c9a227?style=flat-square&logo=linux&logoColor=black&labelColor=f2cc3d"></a>
  <a href="https://github.com/ilyaZar/tapyr.nvim/blob/main/LICENSE"><img src="https://img.shields.io/github/license/ilyaZar/tapyr.nvim?style=flat-square&labelColor=629944&color=446a30"></a>
</p>

<p align="center">
Minimal Neovim workflow for Shiny for Python apps.
</p>

`tapyr.nvim` keeps the usual
[Shiny for Python](https://shiny.posit.co/py/) loop inside Neovim. It finds
projects from an `app.py` import, runs apps and tests through Overseer, and
shows local apps in a small floating panel.

It works with regular Shiny projects, including Appsilon's
[Tapyr template](https://www.appsilon.com/rhinoverse/tapyr). See the Tapyr
[documentation](https://appsilon.github.io/tapyr-docs/) and
[template repository](https://github.com/Appsilon/tapyr-template).

## Requirements

- Neovim 0.10 or newer
- Linux with `/proc` and `ss`
- [`overseer.nvim`](https://github.com/stevearc/overseer.nvim)
- `uv` and Shiny for Python in each app project

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

`:Tapyr` opens the panel directly.

Inside the panel:

- `Tab` and `Shift+Tab` cycle views
- `R` restarts the selected app
- `K` stops the selected app
- `S` opens the selected app
- `Enter` opens files from the Project view
- `q`, `Esc`, or `C` closes the panel

Run `:checkhealth tapyr` to verify external dependencies.

## Limits

Tapyr currently uses fixed `uv run shiny run app.py` and `uv run pytest`
commands. Project detection expects an `app.py` that imports `shiny`.

The Apps view lists the public port for each local Shiny command and hides the
internal redirect listener when the public port is known.

## Development

Run the headless tests:

```bash
./scripts/test
```

Generate the LCOV report after installing `luacov` and
`luacov-reporter-lcov`:

```bash
./scripts/coverage
```

The coverage script writes `coverage/lcov.info` and enforces at least 70% line
coverage across the shipped Lua modules.

## License

MIT
