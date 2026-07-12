local h = require "tests.helpers"
local toggle = require "test-toggle"

local work = h.work "project with spaces"

local function edit(path, filetype)
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.cmd.edit(vim.fn.fnameescape(path))
    if filetype then
        vim.bo.filetype = filetype
    end
end

describe("test-toggle attachment integration", function()
    local original_notify

    before_each(function()
        original_notify = vim.notify
        h.reset_buffers()
    end)

    after_each(function()
        vim.notify = original_notify
        toggle.setup { filetypes = {} }
        h.reset_buffers()
    end)

    it("opens missing targets with special characters", function()
        toggle.setup {
            filetypes = {
                go = { preset = "go", command = "GoToggleTest" },
            },
        }
        local source = vim.fs.joinpath(work, "pkg/name #percent%[part].go")
        edit(source, "go")
        vim.cmd.GoToggleTest()
        assert.equal(
            vim.fs.joinpath(work, "pkg/name #percent%[part]_test.go"),
            vim.api.nvim_buf_get_name(0)
        )
        assert.equal(0, vim.fn.filereadable(vim.api.nvim_buf_get_name(0)))
    end)

    it("opens an existing counterpart", function()
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
        assert.equal(target, vim.api.nvim_buf_get_name(0))
        assert.equal(1, vim.fn.filereadable(target))
    end)

    it("inherits globals and supports entry overrides", function()
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
        assert.is_not_nil(vim.api.nvim_buf_get_commands(bufnr, {}).TSToggleTest)
        assert.is_nil(vim.api.nvim_buf_get_commands(bufnr, {}).TestToggle)
        assert.equal(
            1,
            vim.fn.maparg("<localleader>ot", "n", false, true).buffer
        )
        assert.is_nil(vim.api.nvim_get_commands({}).TSToggleTest)
    end)

    it("keeps mappings opt-in", function()
        toggle.setup {
            filetypes = { python = { preset = "python" } },
        }
        edit(vim.fs.joinpath(work, "no-map.py"), "python")
        assert.is_not_nil(vim.api.nvim_buf_get_commands(0, {}).TestToggle)
        assert.same({}, vim.fn.maparg("<localleader>ot", "n", false, true))
    end)

    it("attaches already loaded buffers", function()
        edit(vim.fs.joinpath(work, "already.js"), "javascript")
        local bufnr = vim.api.nvim_get_current_buf()
        toggle.setup {
            filetypes = {
                javascript = {
                    preset = "javascript",
                    command = "JSToggleTest",
                },
            },
        }
        assert.is_not_nil(vim.api.nvim_buf_get_commands(bufnr, {}).JSToggleTest)
    end)

    it("repeated setup replaces owned registrations", function()
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
        assert.is_nil(commands.JSToggleTest)
        assert.is_not_nil(commands.JavaScriptToggleTest)
        assert.same({}, vim.fn.maparg("<localleader>ot", "n", false, true))
    end)

    it("preserves foreign buffer registrations across setup", function()
        local command_calls = 0
        local command_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(
            command_buf,
            vim.fs.joinpath(work, "foreign.go")
        )
        vim.api.nvim_buf_create_user_command(
            command_buf,
            "TestToggle",
            function()
                command_calls = command_calls + 1
            end,
            { desc = "foreign command" }
        )
        vim.bo[command_buf].filetype = "go"

        local mapping_buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(
            mapping_buf,
            vim.fs.joinpath(work, "foreign-map.go")
        )
        vim.keymap.set("n", "<localleader>ot", "<cmd>echo 'foreign'<cr>", {
            buffer = mapping_buf,
            desc = "foreign mapping",
        })
        vim.bo[mapping_buf].filetype = "go"

        vim.notify = function() end
        toggle.setup { keymap = "<localleader>ot" }
        toggle.setup { filetypes = {} }

        assert.is_not_nil(
            vim.api.nvim_buf_get_commands(command_buf, { builtin = false }).TestToggle
        )
        vim.api.nvim_buf_call(command_buf, function()
            vim.cmd.TestToggle()
        end)
        assert.equal(1, command_calls)
        assert.is_nil(
            vim.api.nvim_buf_get_commands(mapping_buf, { builtin = false }).TestToggle
        )
        local mapping = vim.api.nvim_buf_call(mapping_buf, function()
            return vim.fn.maparg("<localleader>ot", "n", false, true)
        end)
        assert.equal("foreign mapping", mapping.desc)
    end)

    it("does not attach unsupported filetypes", function()
        toggle.setup {
            filetypes = { go = { preset = "go" } },
        }
        edit(vim.fs.joinpath(work, "README.md"), "markdown")
        assert.is_nil(vim.api.nvim_buf_get_commands(0, {}).TestToggle)
        assert.is_false(toggle.attach())
    end)

    it("enables built-in filetype defaults", function()
        toggle.setup()
        edit(vim.fs.joinpath(work, "default.tsx"), "typescriptreact")
        assert.is_not_nil(vim.api.nvim_buf_get_commands(0, {}).TestToggle)
    end)

    it("accepts inline filetype rules", function()
        toggle.setup {
            filetypes = {
                custom = {
                    rules = {
                        {
                            detect = "([^/]+)%.impl$",
                            template = "%1.spec",
                        },
                        {
                            detect = "([^/]+)%.spec$",
                            template = "%1.impl",
                        },
                    },
                    command = "CustomToggleTest",
                },
            },
        }
        edit(vim.fs.joinpath(work, "custom.impl"), "custom")
        vim.cmd.CustomToggleTest()
        assert.equal(
            vim.fs.joinpath(work, "custom.spec"),
            vim.api.nvim_buf_get_name(0)
        )
    end)

    it("keeps targets independent from the working directory", function()
        local source = vim.fs.joinpath(work, "cwd.go")
        edit(source)
        local previous = vim.fn.getcwd()
        vim.cmd.cd(vim.fn.fnameescape(h.root()))
        local target, err = toggle.toggle { preset = "go" }
        vim.cmd.cd(vim.fn.fnameescape(previous))
        assert.is_nil(err)
        assert.equal(vim.fs.joinpath(work, "cwd_test.go"), target)
    end)

    it("warns on unmatched commands without changing buffers", function()
        toggle.setup {
            filetypes = {
                go = { preset = "go", command = "GoToggleTest" },
            },
        }
        edit(vim.fs.joinpath(work, "README.md"), "go")
        local before = vim.api.nvim_get_current_buf()
        local notification
        vim.notify = function(message)
            notification = message
        end
        vim.cmd.GoToggleTest()
        assert.equal(before, vim.api.nvim_get_current_buf())
        assert.truthy(notification:find("no matching rule", 1, true))
    end)

    it("returns an error for unnamed buffers", function()
        local target, err = toggle.toggle { preset = "lua" }
        assert.is_nil(target)
        assert.equal("current buffer has no file name", err)
    end)
end)
