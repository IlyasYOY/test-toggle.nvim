# test-toggle.nvim Agent Guidelines

## Project shape

- Support Neovim 0.11 and newer with no third-party runtime dependencies.
- Public behavior lives in `lua/test-toggle/init.lua`; built-in path rules
  live in `lua/test-toggle/presets.lua`.
- Preset and resolution specs are colocated as `*_spec.lua`. Buffer
  attachment and filesystem integration specs stay under `tests/`.
- `setup()` owns the automatic `FileType` attachment lifecycle.

## Runtime contracts

- Preserve the `register`, `resolve`, `toggle`, `attach`, and `setup`
  APIs and their return shapes.
- Keep commands and mappings buffer-local; mappings remain opt-in.
- Repeated setup must remove only commands, mappings, and autocmds owned by the
  plugin. Preserve foreign buffer registrations.
- Preserve all built-in preset IDs and path transformations.
- Normalize paths independently of the current working directory and keep
  special-character paths safe through `fnameescape()`.
- Opening a missing counterpart as a new buffer is expected behavior.

## Development

- `make check` is the canonical non-mutating format, lint, help, and test
  command.
- `make test` runs the isolated module and attachment suites.
- Before compatibility work is complete, run:
  - `make test NVIM_VERSION=v0.11.7`
  - `make test NVIM_VERSION=v0.12.5`
  - `make test NVIM_VERSION=nightly` as a compatibility probe
- A selected spec can be passed through
  `require("tests.runner").run({ files = { ... }, verbose = true })`.
- Create filesystem fixtures only under ignored `.test-work`; never touch
  real project files or editor state.

## Style and documentation

- StyLua uses 4 spaces, 80 columns, Unix line endings, preferred double quotes,
  and omitted call parentheses where supported.
- Keep rule validation explicit and errors useful to callers.
- Update `README.md`, `doc/test-toggle.txt`, tracked `doc/tags`, and
  health coverage when requirements or public behavior changes.

## Repository safety

- Do not commit, push, tag, publish, or dispatch a release unless the user
  explicitly asks.
- Preserve unrelated worktree changes and ignored local fixtures.
