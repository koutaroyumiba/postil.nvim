<div align="center">

# postil.nvim

**Send a Neovim visual selection, its source location, and an instruction to an interactive command running a tmux pane.**

<a href="https://github.com/koutaroyumiba/postil.nvim/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/koutaroyumiba/postil.nvim?style=flat-square&color=ca9ee6" /></a>
<a href="https://github.com/koutaroyumiba/postil.nvim/actions/workflows/ci.yml"><img alt="CI status" src="https://img.shields.io/github/actions/workflow/status/koutaroyumiba/postil.nvim/ci.yml?branch=main&style=flat-square&label=CI" /></a>
<img alt="Platforms: macOS and Linux" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-8caaee?style=flat-square&logo=apple&logoColor=white" />
<img alt="Minimum Neovim version: 0.12" src="https://img.shields.io/badge/Neovim-0.12%2B-ef9f76?style=flat-square&logo=neovim&logoColor=white" />
<a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-a6d189?style=flat-square" /></a>

</div>

> Early development. See [CHANGELOG.md](CHANGELOG.md) for the planned behaviour.

## Overview

The primary workflow is:

1. Select text in visual mode.
2. Invoke `PostilSend` through a user keymap.
3. Write an instruction in an editable floating buffer; use `:w` to submit or `:q!` to cancel.
4. Reuse the configured tmux pane, or create one automatically if no valid target exists.
5. Paste a structured message into the pane and optionally submit it.

`PostilPreview` follows the same selection and instruction flow, then opens the formatted message in a read-only floating buffer without contacting tmux.

<div align="center">
  <img alt="PostilPreview demonstration" src="assets/postil-preview.gif" />
</div>

## Requirements

- Neovim 0.12 or newer
- `tmux` available on `PATH`
- Neovim running inside tmux for sending; previews work without tmux

## Preview

Postil installs no default keymaps. To preview the formatted message while developing or reviewing a prompt:

```lua
vim.keymap.set("x", "<leader>aP", function()
  require("postil").preview_visual()
end, { desc = "Preview selection with Postil" })
```

Write a single- or multiline instruction in the floating buffer. Use `:w` to submit it and `:q!` to cancel. Close the resulting preview with `q` or `<Esc>`.

## Commands

- `:PostilSend[!]` sends the latest visual selection; `!` inverts automatic submission.
- `:PostilPreview` previews the formatted selection without using tmux.
- `:PostilTarget [pane-id]` chooses a target pane.
- `:PostilNew` creates a target pane.
- `:PostilClearTarget` forgets the current target.
- `:PostilStatus` shows the current configuration and target.

## Lua API

```lua
require("postil").setup(opts)
require("postil").send_visual(opts)
require("postil").preview_visual()
require("postil").select_target()
require("postil").new_target()
require("postil").clear_target()
require("postil").status()
```

The `prompt` setup option controls the title of the editable instruction window.

## License

[MIT](LICENSE)
