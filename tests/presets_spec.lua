local h = require "tests.helpers"
local toggle = require "test-toggle"

local root = h.root ".test-work/project with spaces"

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
        "complex basename",
        "go",
        "pkg/name with #percent%[part].go",
        "pkg/name with #percent%[part]_test.go",
    },
}

local tests = {}
for _, case in ipairs(cases) do
    tests[#tests + 1] = h.test(case[1], function()
        local source = vim.fs.joinpath(root, case[3])
        local expected = vim.fs.normalize(vim.fs.joinpath(root, case[4]))
        local actual, err = toggle.resolve(source, case[2])
        h.eq(nil, err)
        h.eq(expected, actual)
    end)
end

tests[#tests + 1] = h.test("returns an error for an unmatched file", function()
    local target, err = toggle.resolve(vim.fs.joinpath(root, "README.md"), "go")
    h.eq(nil, target)
    h.truthy(err:find("no matching rule", 1, true))
end)

tests[#tests + 1] = h.test(
    "does not treat Java integration tests as unit tests",
    function()
        local target = toggle.resolve(
            vim.fs.joinpath(root, "src/integrationTest/java/WidgetTest.java"),
            "java"
        )
        h.eq(nil, target)
    end
)

tests[#tests + 1] = h.test("registers template and callback rules", function()
    toggle.register("custom", {
        { detect = "([^/]+)%.impl$", template = "%1.spec" },
        {
            detect = "([^/]+)%.spec$",
            transform = function(path)
                return path:gsub("%.spec$", ".impl")
            end,
        },
    })
    h.eq(
        vim.fs.joinpath(root, "name.spec"),
        toggle.resolve(vim.fs.joinpath(root, "name.impl"), "custom")
    )
    h.eq(
        vim.fs.joinpath(root, "name.impl"),
        toggle.resolve(vim.fs.joinpath(root, "name.spec"), "custom")
    )
end)

tests[#tests + 1] = h.test("validates malformed rules", function()
    local ok, err = pcall(toggle.register, "broken", {
        { detect = "%.go$", template = ".test.go", transform = function() end },
    })
    h.eq(false, ok)
    h.truthy(tostring(err):find("exactly one", 1, true))
end)

return tests
