# Changelog

All notable changes to `postil.nvim` will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Planned for 1.0.0

- Capture characterwise, linewise, and blockwise Neovim visual selections.
- Prompt for an instruction and compose it with file, range, filetype, root, and selection context.
- Send multiline messages safely to a tmux pane without shell interpolation.
- Select and remember an existing tmux pane by stable pane ID.
- Automatically create a configurable detached pane when no live target exists.
- Start any configured interactive command in the project directory.
- Recreate the target automatically after its pane is closed.
- Support optional automatic Enter submission and one-shot inversion with `:PostilSend!`.
- Provide commands to send, select a target, create a target, clear a target, and inspect status.
- Support a custom message formatter through `setup()`.
- Support lazy.nvim installation without third-party runtime dependencies.
- Include headless checks for selection and formatting logic.

[Unreleased]: https://github.com/koutaroyumiba/postil.nvim/compare/v1.0.0...HEAD
