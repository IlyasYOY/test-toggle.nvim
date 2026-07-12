local M = {}

local function check_function(name, value)
    if type(value) == "function" then
        vim.health.ok(name .. " is available")
    else
        vim.health.error(name .. " is not available")
    end
end

function M.check()
    vim.health.start "test-toggle.nvim"

    if vim.fn.has "nvim-0.11" == 1 then
        vim.health.ok "Neovim 0.11 or newer is available"
    else
        vim.health.error "test-toggle.nvim requires Neovim 0.11 or newer"
    end

    local loaded, module = pcall(require, "test-toggle")
    if loaded and type(module.setup) == "function" then
        vim.health.ok "test-toggle.nvim is available"
    else
        vim.health.error(
            "test-toggle.nvim could not be loaded",
            loaded and nil or tostring(module)
        )
    end

    check_function("vim.fs.normalize", vim.fs.normalize)
    check_function(
        "vim.api.nvim_buf_create_user_command",
        vim.api.nvim_buf_create_user_command
    )
    vim.health.ok "No third-party runtime dependencies are required"
end

return M
