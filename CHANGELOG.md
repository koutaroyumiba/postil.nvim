# Changelog

All notable changes to `postil.nvim` will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## [1.0.0] - 2026-10-07

### Added

- Capture characterwise, linewise, and blockwise visual selections.
- Preserve the selected text exactly, including partial first and last lines.
- Include the absolute file path, selected line range, Neovim filetype, and selected text in the outgoing message.
- Compose a free-form, multiline instruction in an editable floating buffer.
- Cancel cleanly when the instruction buffer is dismissed or empty.
- Preview the formatted selection and instruction without contacting tmux.
- Address tmux panes by stable pane ID, such as `%7`, rather than pane index.
- Reuse a live target pane across sends during the current Neovim process.
- Let the user select any pane in the current tmux session.
- Automatically create a pane when no target is configured or the remembered pane no longer exists.
- Start a configurable command in an automatically created pane.
- Create the pane in the current project directory.
- Paste multiline content without shell interpolation or simulated typing.
- Optionally press Enter after pasting.
- Provide Lua functions and user commands for sending, choosing, creating, clearing, and inspecting the target.
- Notify the user of actionable failures through `vim.notify()`.
- Work with lazy.nvim through a conventional `require("postil").setup()` entry point.
- Require no third-party Lua dependencies.


[Unreleased]: https://github.com/koutaroyumiba/postil.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/koutaroyumiba/postil.nvim/releases/tag/v1.0.0
