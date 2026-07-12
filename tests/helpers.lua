local M = {}

function M.test(name, run)
    return { name = name, run = run }
end

function M.eq(expected, actual)
    if not vim.deep_equal(expected, actual) then
        error(
            ("expected %s, got %s"):format(
                vim.inspect(expected),
                vim.inspect(actual)
            ),
            2
        )
    end
end

function M.truthy(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

function M.root(path)
    local source = debug.getinfo(1, "S").source:sub(2)
    local repo = vim.fn.fnamemodify(source, ":p:h:h")
    return path and vim.fs.joinpath(repo, path) or repo
end

function M.reset_buffers()
    vim.cmd "silent! %bwipeout!"
    vim.cmd "enew"
end

return M
