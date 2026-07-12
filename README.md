# test-toggle.nvim

A small, dependency-free Neovim plugin for switching between source and test
files. It provides reusable path rules, built-in language presets, a
buffer-local command, and an opt-in buffer-local mapping.

## Requirements

- Neovim 0.11 or newer

No third-party plugins are required at runtime.

## Installation

With Neovim's built-in package manager:

```lua
vim.pack.add {
    "https://github.com/IlyasYOY/test-toggle.nvim",
}
```

With lazy.nvim:

```lua
{ "IlyasYOY/test-toggle.nvim" }
```

## Usage

Configure filetypes once from your plugin configuration:

```lua
require("test-toggle").setup {
    keymap = "<localleader>ot",
    filetypes = {
        go = { preset = "go", command = "GoToggleTest" },
        typescriptreact = {
            preset = "tsx",
            command = "TSXToggleTest",
        },
    },
}
```

`setup()` installs a `FileType` autocmd and also attaches already loaded
matching buffers. Commands and mappings are buffer-local. The common mapping
defaults to `false`, so `ot` or any other mapping is never created unless
requested. Filetype entries inherit common `command` and `keymap` values and
may override either one.

Built-in presets are `go`, `java`, `python`, `javascript`, `typescript`, `tsx`,
and `lua`. Java supports `src/main/java` to `src/test/java` with the `Test`
class suffix. Kotlin and integration-test source sets are intentionally not
included.

## Rules and public API

A rule has a Lua pattern in `detect` and exactly one transformation:

```lua
local rules = {
    { detect = "([^/]+)_test%.go$", template = "%1.go" },
    { detect = "([^/]+)%.go$", template = "%1_test.go" },
    {
        detect = "/generated/",
        transform = function(path)
            return path:gsub("/generated/", "/source/", 1)
        end,
    },
}
```

For a template rule, `detect` is also the pattern passed to `string.gsub`.
Callback transforms receive a normalized absolute path and must return a
non-empty path.

```lua
local toggle = require "test-toggle"

toggle.register("custom", rules)

toggle.setup {
    keymap = false,
    filetypes = {
        custom = {
            preset = "custom", -- or rules = rules
            command = "CustomToggleTest",
        },
    },
}

local target, err = toggle.resolve("src/widget.go", "go")
local opened, open_err = toggle.toggle { preset = "go", bufnr = 0 }
```

### `setup(opts)`

Validates configuration and automatically attaches configured filetypes.
Options:

- `command`: inherited command name, default `TestToggle`
- `keymap`: inherited mapping or `false`, default `false`
- `filetypes`: map of filetype names to entries containing `preset` or `rules`,
  plus optional `command` and `keymap` overrides

Calling `setup()` without options enables the seven built-in filetype mappings
with `TestToggle` and no keymap. When `filetypes` is supplied, it replaces that
default map. Repeated setup calls replace the plugin's previous autocmds,
commands, and mappings.

### `register(name, rules)`

Registers or replaces a named preset after validating every rule.

### `attach(bufnr)`

Attaches the configuration selected by the buffer's filetype. The buffer
defaults to the current buffer. Normally `setup()` calls this automatically.

### `resolve(path, preset_or_rules)`

Returns an absolute target path, or `nil, error` when no rule matches or a
transformation is invalid.

### `toggle(opts)`

Resolves and edits the counterpart for `opts.bufnr`. Paths are absolute and do
not depend on the current working directory. An absent counterpart is opened
as a new buffer. Unnamed and unmatched buffers return an error; commands and
mappings display that error as a warning.

## Development

```sh
make check
make test NVIM_VERSION=v0.11.7
```

`make check` runs formatting checks, Luacheck, headless Neovim tests, and help
tag validation.

## License

MIT. See [LICENSE](./LICENSE).
