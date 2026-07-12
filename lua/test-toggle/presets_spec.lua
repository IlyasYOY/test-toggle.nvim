local h = require "tests.helpers"
local toggle = require "test-toggle"

local root = h.work "project with spaces"

local cases = {
    { "go source", "go", "pkg/widget.go", "pkg/widget_test.go" },
    { "go test", "go", "pkg/widget_test.go", "pkg/widget.go" },
    {
        "java source",
        "java",
        "src/main/java/com/example/Widget.java",
        "src/test/java/com/example/WidgetTest.java",
    },
    {
        "java test",
        "java",
        "src/test/java/com/example/WidgetTest.java",
        "src/main/java/com/example/Widget.java",
    },
    { "python source", "python", "pkg/widget.py", "pkg/test_widget.py" },
    { "python test", "python", "pkg/test_widget.py", "pkg/widget.py" },
    {
        "javascript source",
        "javascript",
        "src/widget.js",
        "src/widget.test.js",
    },
    {
        "javascript test",
        "javascript",
        "src/widget.test.js",
        "src/widget.js",
    },
    {
        "typescript source",
        "typescript",
        "src/widget.ts",
        "src/widget.test.ts",
    },
    {
        "typescript test",
        "typescript",
        "src/widget.test.ts",
        "src/widget.ts",
    },
    { "tsx source", "tsx", "src/widget.tsx", "src/widget.test.tsx" },
    { "tsx test", "tsx", "src/widget.test.tsx", "src/widget.tsx" },
    { "lua source", "lua", "lua/widget.lua", "lua/widget_spec.lua" },
    { "lua test", "lua", "lua/widget_spec.lua", "lua/widget.lua" },
    {
        "special basename",
        "go",
        "pkg/name with #percent%[part].go",
        "pkg/name with #percent%[part]_test.go",
    },
}

describe("test-toggle presets", function()
    for _, case in ipairs(cases) do
        it("resolves " .. case[1], function()
            local source = vim.fs.joinpath(root, case[3])
            local expected = vim.fs.normalize(vim.fs.joinpath(root, case[4]))
            local actual, err = toggle.resolve(source, case[2])
            assert.is_nil(err)
            assert.equal(expected, actual)
        end)
    end

    it("does not treat Java integration tests as unit tests", function()
        local target = toggle.resolve(
            vim.fs.joinpath(root, "src/integrationTest/java/WidgetTest.java"),
            "java"
        )
        assert.is_nil(target)
    end)
end)
