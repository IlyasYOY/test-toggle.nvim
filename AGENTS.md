# test-toggle.nvim Agent Guidelines

- Support Neovim 0.11 and newer.
- Keep runtime behavior dependency-free.
- Keep commands and mappings buffer-local; mappings are opt-in.
- Keep filetype settings in `setup()`; it owns automatic `FileType` attachment.
- `make check` is the canonical format, lint, help, and test command.
- Do not commit or push unless the user explicitly asks.
