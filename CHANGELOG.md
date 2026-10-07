# Changelog

All notable changes to `postil.nvim` will be documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-07

### Added

- Added exact characterwise, linewise, and blockwise visual-selection capture.
- Added source path, line range, filetype, project-root, and selected-text context.
- Added an editable floating buffer for single- and multiline instructions.
- Added formatted-message previews without contacting tmux.
- Added stable tmux pane targeting, selection, detached creation, reuse, and recovery.
- Added bracketed multiline paste through uniquely named tmux buffers without shell interpolation.
- Added optional automatic submission and one-shot inversion with `:PostilSend!`.
- Added configurable destination commands, split layout, startup delay, root markers, and message formatting.
- Added public Lua functions and `:Postil*` user commands.
- Added strict configuration validation and headless selection and formatting checks.
- Added lazy.nvim support without third-party Lua dependencies.

[Unreleased]: https://github.com/koutaroyumiba/postil.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/koutaroyumiba/postil.nvim/releases/tag/v1.0.0
