local h = require "tests.helpers"
local toggle = require "test-toggle"

describe("test-toggle resolution", function()
    after_each(function()
        toggle.setup { filetypes = {} }
    end)

    it("registers template and callback rules", function()
        toggle.register("custom", {
            { detect = "([^/]+)%.impl$", template = "%1.spec" },
            {
                detect = "([^/]+)%.spec$",
                transform = function(path)
                    return path:gsub("%.spec$", ".impl")
                end,
            },
        })
        local root = h.work "custom"
        assert.equal(
            vim.fs.joinpath(root, "name.spec"),
            toggle.resolve(vim.fs.joinpath(root, "name.impl"), "custom")
        )
        assert.equal(
            vim.fs.joinpath(root, "name.impl"),
            toggle.resolve(vim.fs.joinpath(root, "name.spec"), "custom")
        )
    end)

    it("returns descriptive errors for unmatched and unnamed paths", function()
        local target, err = toggle.resolve(h.work "README.md", "go")
        assert.is_nil(target)
        assert.truthy(err:find("no matching rule", 1, true))

        target, err = toggle.resolve("", "go")
        assert.is_nil(target)
        assert.equal("current buffer has no file name", err)
    end)

    it("reports unknown presets and invalid transformations", function()
        local target, err = toggle.resolve(h.work "name.go", "missing")
        assert.is_nil(target)
        assert.truthy(err:find("unknown preset", 1, true))

        target, err = toggle.resolve(h.work "name.go", {
            {
                detect = "%.go$",
                transform = function()
                    error "failed"
                end,
            },
        })
        assert.is_nil(target)
        assert.truthy(err:find("transform failed", 1, true))

        target, err = toggle.resolve(h.work "name.go", {
            {
                detect = "%.go$",
                transform = function(path)
                    return path
                end,
            },
        })
        assert.is_nil(target)
        assert.truthy(err:find("did not change", 1, true))
    end)

    it("validates preset and rule schemas", function()
        assert.has_error(function()
            toggle.register("", {})
        end, "preset name")
        assert.has_error(function()
            toggle.register("empty", {})
        end, "non-empty list")
        assert.has_error(function()
            toggle.register("broken", {
                {
                    detect = "%.go$",
                    template = ".test.go",
                    transform = function() end,
                },
            })
        end, "exactly one")
    end)

    it("validates setup configuration", function()
        assert.has_error(function()
            toggle.setup { command = "" }
        end, "command must be")
        assert.has_error(function()
            toggle.setup { keymap = true }
        end, "keymap must be")
        assert.has_error(function()
            toggle.setup { filetypes = {} }
            toggle.setup {
                filetypes = {
                    go = { preset = "go", rules = {} },
                },
            }
        end, "mutually exclusive")
        assert.has_error(function()
            toggle.setup {
                filetypes = {
                    go = { preset = "missing" },
                },
            }
        end, "unknown preset")
    end)
end)
