local function java_source_to_test(path)
    path = path:gsub("/src/main/java/", "/src/test/java/", 1)
    return path:gsub("([^/]+)%.java$", "%1Test.java", 1)
end

local function java_test_to_source(path)
    path = path:gsub("/src/test/java/", "/src/main/java/", 1)
    return path:gsub("([^/]+)Test%.java$", "%1.java", 1)
end

return {
    go = {
        { detect = "([^/]+)_test%.go$", template = "%1.go" },
        { detect = "([^/]+)%.go$", template = "%1_test.go" },
    },
    java = {
        {
            detect = "/src/test/java/.*Test%.java$",
            transform = java_test_to_source,
        },
        {
            detect = "/src/main/java/.*%.java$",
            transform = java_source_to_test,
        },
    },
    python = {
        { detect = "test_([^/]+)%.py$", template = "%1.py" },
        { detect = "([^/]+)%.py$", template = "test_%1.py" },
    },
    javascript = {
        { detect = "([^/]+)%.test%.js$", template = "%1.js" },
        { detect = "([^/]+)%.js$", template = "%1.test.js" },
    },
    typescript = {
        { detect = "([^/]+)%.test%.ts$", template = "%1.ts" },
        { detect = "([^/]+)%.ts$", template = "%1.test.ts" },
    },
    tsx = {
        { detect = "([^/]+)%.test%.tsx$", template = "%1.tsx" },
        { detect = "([^/]+)%.tsx$", template = "%1.test.tsx" },
    },
    lua = {
        { detect = "([^/]+)_spec%.lua$", template = "%1.lua" },
        { detect = "([^/]+)%.lua$", template = "%1_spec.lua" },
    },
}
