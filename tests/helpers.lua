local M = {}

function M.root(path)
    local source = debug.getinfo(1, "S").source:sub(2)
    local repo = vim.fn.fnamemodify(source, ":p:h:h")
    return path and vim.fs.joinpath(repo, path) or repo
end

function M.work(path)
    local base = vim.env.TEST_TOGGLE_TEST_WORK or M.root ".test-work"
    base = vim.fn.resolve(vim.fn.fnamemodify(base, ":p"))
    base = vim.fs.normalize(base)
    return path and vim.fs.joinpath(base, path) or base
end

function M.reset_buffers()
    vim.cmd "silent! %bwipeout!"
    vim.cmd "enew"
end

return M
