# tapyr.nvim

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

The Apps view lists each local port owned by a Shiny command. Reload mode can
therefore show more than one port for the same app.

## Development

Run the headless tests:

```bash
./scripts/test
```

## License

MIT
