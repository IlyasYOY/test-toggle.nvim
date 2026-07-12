local h = require "tests.helpers"
local toggle = require "test-toggle"

local work = h.root ".test-work/project with spaces"

local function edit(path, filetype)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.cmd.edit(vim.fn.fnameescape(path))
    if filetype then
        vim.bo.filetype = filetype
    end
end

local tests = {}

tests[#tests + 1] = h.test(
    "setup opens missing targets with special characters",
    function()
        h.reset_buffers()
        toggle.setup {
            filetypes = {
                go = { preset = "go", command = "GoToggleTest" },
            },
        }
        local source = vim.fs.joinpath(work, "pkg/name #percent%[part].go")
        edit(source, "go")
        vim.cmd.GoToggleTest()
        h.eq(
            vim.fs.joinpath(work, "pkg/name #percent%[part]_test.go"),
            vim.api.nvim_buf_get_name(0)
        )
        h.eq(0, vim.fn.filereadable(vim.api.nvim_buf_get_name(0)))
    end
)

tests[#tests + 1] = h.test("setup opens an existing counterpart", function()
    h.reset_buffers()
    toggle.setup {
        filetypes = {
            lua = { preset = "lua", command = "LuaToggleTest" },
        },
    }
    local source = vim.fs.joinpath(work, "existing.lua")
    local target = vim.fs.joinpath(work, "existing_spec.lua")
    vim.fn.mkdir(vim.fs.dirname(source), "p")
    vim.fn.writefile({ "return true" }, source)
    vim.fn.writefile({ "return true" }, target)
    edit(source, "lua")
    vim.cmd.LuaToggleTest()
    h.eq(target, vim.api.nvim_buf_get_name(0))
    h.eq(1, vim.fn.filereadable(target))
end)

tests[#tests + 1] = h.test(
    "global settings are inherited and entries override commands",
    function()
        h.reset_buffers()
        toggle.setup {
            command = "TestToggle",
            keymap = "<localleader>ot",
            filetypes = {
                typescript = {
                    preset = "typescript",
                    command = "TSToggleTest",
                },
            },
        }
        edit(vim.fs.joinpath(work, "local.ts"), "typescript")
        local bufnr = vim.api.nvim_get_current_buf()
        h.truthy(vim.api.nvim_buf_get_commands(bufnr, {}).TSToggleTest)
        h.eq(nil, vim.api.nvim_buf_get_commands(bufnr, {}).TestToggle)
        h.eq(1, vim.fn.maparg("<localleader>ot", "n", false, true).buffer)
        h.eq(nil, vim.api.nvim_get_commands({}).TSToggleTest)
    end
)

tests[#tests + 1] = h.test("keymap is opt-in", function()
    h.reset_buffers()
    toggle.setup {
        filetypes = { python = { preset = "python" } },
    }
    edit(vim.fs.joinpath(work, "no-map.py"), "python")
    h.truthy(vim.api.nvim_buf_get_commands(0, {}).TestToggle)
    h.eq({}, vim.fn.maparg("<localleader>ot", "n", false, true))
end)

tests[#tests + 1] = h.test("setup attaches already loaded buffers", function()
    h.reset_buffers()
    edit(vim.fs.joinpath(work, "already.js"), "javascript")
    local bufnr = vim.api.nvim_get_current_buf()
    toggle.setup {
        filetypes = {
            javascript = { preset = "javascript", command = "JSToggleTest" },
        },
    }
    h.truthy(vim.api.nvim_buf_get_commands(bufnr, {}).JSToggleTest)
end)

tests[#tests + 1] = h.test(
    "repeated setup replaces owned registrations",
    function()
        h.reset_buffers()
        edit(vim.fs.joinpath(work, "reattach.js"), "javascript")
        local bufnr = vim.api.nvim_get_current_buf()
        toggle.setup {
            keymap = "<localleader>ot",
            filetypes = {
                javascript = {
                    preset = "javascript",
                    command = "JSToggleTest",
                },
            },
        }
        toggle.setup {
            filetypes = {
                javascript = {
                    preset = "javascript",
                    command = "JavaScriptToggleTest",
                },
            },
        }
        local commands = vim.api.nvim_buf_get_commands(bufnr, {})
        h.eq(nil, commands.JSToggleTest)
        h.truthy(commands.JavaScriptToggleTest)
        h.eq({}, vim.fn.maparg("<localleader>ot", "n", false, true))
    end
)

tests[#tests + 1] = h.test("unsupported filetypes are not attached", function()
    h.reset_buffers()
    toggle.setup {
        filetypes = { go = { preset = "go" } },
    }
    edit(vim.fs.joinpath(work, "README.md"), "markdown")
    h.eq(nil, vim.api.nvim_buf_get_commands(0, {}).TestToggle)
    h.eq(false, toggle.attach())
end)

tests[#tests + 1] = h.test("setup defaults cover built-in filetypes", function()
    h.reset_buffers()
    toggle.setup()
    edit(vim.fs.joinpath(work, "default.tsx"), "typescriptreact")
    h.truthy(vim.api.nvim_buf_get_commands(0, {}).TestToggle)
end)

tests[#tests + 1] = h.test("setup accepts inline filetype rules", function()
    h.reset_buffers()
    toggle.setup {
        filetypes = {
            custom = {
                rules = {
                    { detect = "([^/]+)%.impl$", template = "%1.spec" },
                    { detect = "([^/]+)%.spec$", template = "%1.impl" },
                },
                command = "CustomToggleTest",
            },
        },
    }
    edit(vim.fs.joinpath(work, "custom.impl"), "custom")
    vim.cmd.CustomToggleTest()
    h.eq(vim.fs.joinpath(work, "custom.spec"), vim.api.nvim_buf_get_name(0))
end)

tests[#tests + 1] = h.test("changing CWD does not change the target", function()
    h.reset_buffers()
    local source = vim.fs.joinpath(work, "cwd.go")
    edit(source)
    local previous = vim.fn.getcwd()
    vim.cmd.cd(vim.fn.fnameescape(h.root()))
    local target, err = toggle.toggle { preset = "go" }
    vim.cmd.cd(vim.fn.fnameescape(previous))
    h.eq(nil, err)
    h.eq(vim.fs.joinpath(work, "cwd_test.go"), target)
end)

tests[#tests + 1] = h.test(
    "unmatched commands warn without changing buffers",
    function()
        h.reset_buffers()
        toggle.setup {
            filetypes = {
                go = { preset = "go", command = "GoToggleTest" },
            },
        }
        edit(vim.fs.joinpath(work, "README.md"), "go")
        local before = vim.api.nvim_get_current_buf()
        local notification
        local original_notify = vim.notify
        vim.notify = function(message)
            notification = message
        end
        vim.cmd.GoToggleTest()
        vim.notify = original_notify
        h.eq(before, vim.api.nvim_get_current_buf())
        h.truthy(notification:find("no matching rule", 1, true))
    end
)

tests[#tests + 1] = h.test("unnamed buffers return an error", function()
    h.reset_buffers()
    local target, err = toggle.toggle { preset = "lua" }
    h.eq(nil, target)
    h.eq("current buffer has no file name", err)
end)

return tests
