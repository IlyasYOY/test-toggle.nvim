local M = {}

local registry = vim.deepcopy(require "test-toggle.presets")
local attached = {}
local augroup

local default_filetypes = {
    go = { preset = "go" },
    java = { preset = "java" },
    python = { preset = "python" },
    javascript = { preset = "javascript" },
    typescript = { preset = "typescript" },
    typescriptreact = { preset = "tsx" },
    lua = { preset = "lua" },
}

local config = {
    command = "TestToggle",
    keymap = false,
    filetypes = vim.deepcopy(default_filetypes),
}

local function normalize_path(path)
    return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function validate_rules(rules)
    if not vim.islist(rules) or #rules == 0 then
        error "rules must be a non-empty list"
    end

    for index, rule in ipairs(rules) do
        if type(rule) ~= "table" then
            error(("rule %d must be a table"):format(index))
        end
        if type(rule.detect) ~= "string" or rule.detect == "" then
            error(("rule %d detect must be a non-empty string"):format(index))
        end

        local has_template = type(rule.template) == "string"
        local has_transform = type(rule.transform) == "function"
        if has_template == has_transform then
            error(
                ("rule %d must define exactly one of template or transform"):format(
                    index
                )
            )
        end
    end
end

local function resolve_rules(spec)
    if type(spec) == "string" then
        local rules = registry[spec]
        if not rules then
            return nil, "unknown preset: " .. spec
        end
        return rules
    end

    local ok, err = pcall(validate_rules, spec)
    if not ok then
        return nil, err
    end
    return spec
end

local function notify_error(err)
    vim.notify("test-toggle: " .. err, vim.log.levels.WARN)
end

local function option_spec(opts)
    if opts.preset ~= nil and opts.rules ~= nil then
        return nil, "preset and rules are mutually exclusive"
    end
    local spec = opts.preset or opts.rules
    if spec == nil then
        return nil, "preset or rules is required"
    end
    return spec, nil
end

local function validate_command(name, value)
    if type(value) ~= "string" or value == "" then
        error(name .. " must be a non-empty string")
    end
end

local function validate_keymap(name, value)
    if value ~= false and (type(value) ~= "string" or value == "") then
        error(name .. " must be false or a non-empty string")
    end
end

local function resolve_config(opts)
    opts = vim.deepcopy(opts or {})
    local keymap = opts.keymap
    if keymap == nil then
        keymap = false
    end
    local result = {
        command = opts.command or "TestToggle",
        keymap = keymap,
        filetypes = opts.filetypes == nil and vim.deepcopy(default_filetypes)
            or opts.filetypes,
    }

    validate_command("command", result.command)
    validate_keymap("keymap", result.keymap)
    if
        type(result.filetypes) ~= "table"
        or (next(result.filetypes) ~= nil and vim.islist(result.filetypes))
    then
        error "filetypes must be a map"
    end

    for filetype, entry in pairs(result.filetypes) do
        if type(filetype) ~= "string" or filetype == "" then
            error "filetype names must be non-empty strings"
        end
        if type(entry) ~= "table" then
            error("filetypes.%s must be a table"):format(filetype)
        end
        local spec, spec_err = option_spec(entry)
        if not spec then
            error(("filetypes.%s: %s"):format(filetype, spec_err))
        end
        local rules, rules_err = resolve_rules(spec)
        if not rules then
            error(("filetypes.%s: %s"):format(filetype, rules_err))
        end
        if entry.command ~= nil then
            validate_command(
                "filetypes." .. filetype .. ".command",
                entry.command
            )
        end
        if entry.keymap ~= nil then
            validate_keymap("filetypes." .. filetype .. ".keymap", entry.keymap)
        end
    end
    return result
end

local function effective_options(filetype)
    local entry = config.filetypes[filetype]
    if not entry then
        return nil
    end
    local keymap = entry.keymap
    if keymap == nil then
        keymap = config.keymap
    end
    return {
        preset = entry.preset,
        rules = entry.rules,
        command = entry.command or config.command,
        keymap = keymap,
    }
end

--- Register or replace a named set of toggle rules.
--- @param name string
--- @param rules table[]
function M.register(name, rules)
    if type(name) ~= "string" or name == "" then
        error "preset name must be a non-empty string"
    end
    validate_rules(rules)
    registry[name] = vim.deepcopy(rules)
end

--- Resolve a path using a named preset or a list of rules.
--- @param path string
--- @param spec string|table[]
--- @return string? target
--- @return string? error
function M.resolve(path, spec)
    if type(path) ~= "string" or path == "" then
        return nil, "current buffer has no file name"
    end

    local rules, rules_err = resolve_rules(spec)
    if not rules then
        return nil, rules_err
    end

    path = normalize_path(path)
    for _, rule in ipairs(rules) do
        if path:find(rule.detect) then
            local target
            if rule.template ~= nil then
                target = path:gsub(rule.detect, rule.template, 1)
            else
                local ok, result = pcall(rule.transform, path)
                if not ok then
                    return nil, "transform failed: " .. tostring(result)
                end
                target = result
            end

            if type(target) ~= "string" or target == "" then
                return nil, "transform must return a non-empty path"
            end
            target = normalize_path(target)
            if target == path then
                return nil, "transform did not change the path"
            end
            return target, nil
        end
    end

    return nil, "no matching rule for " .. path
end

--- Resolve and edit the counterpart of a buffer's file.
--- @param opts { bufnr?: integer, preset?: string, rules?: table[] }
--- @return string? target
--- @return string? error
function M.toggle(opts)
    opts = opts or {}
    local bufnr = opts.bufnr or 0
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil, "invalid buffer"
    end

    local spec, spec_err = option_spec(opts)
    if not spec then
        return nil, spec_err
    end

    local target, err = M.resolve(vim.api.nvim_buf_get_name(bufnr), spec)
    if not target then
        return nil, err
    end

    local ok, edit_err = pcall(vim.cmd.edit, vim.fn.fnameescape(target))
    if not ok then
        return nil, "could not open target: " .. tostring(edit_err)
    end
    return target, nil
end

local function detach_owned(bufnr)
    local previous = attached[bufnr]
    if not previous then
        return
    end
    if vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_del_user_command, bufnr, previous.command)
        if previous.keymap then
            pcall(vim.keymap.del, "n", previous.keymap, { buffer = bufnr })
        end
    end
    attached[bufnr] = nil
end

local function cleanup()
    if augroup then
        pcall(vim.api.nvim_del_augroup_by_id, augroup)
        augroup = nil
    end
    local buffers = vim.tbl_keys(attached)
    for _, bufnr in ipairs(buffers) do
        detach_owned(bufnr)
    end
end

local function has_buffer_mapping(bufnr, lhs)
    return vim.api.nvim_buf_call(bufnr, function()
        local mapping = vim.fn.maparg(lhs, "n", false, true)
        return type(mapping) == "table"
            and next(mapping) ~= nil
            and mapping.buffer == 1
    end)
end

local function attach_with_options(bufnr, opts)
    local command = opts.command
    local keymap = opts.keymap
    detach_owned(bufnr)
    if vim.api.nvim_buf_get_commands(bufnr, {})[command] then
        return nil, "buffer command already exists: " .. command
    end
    if keymap and has_buffer_mapping(bufnr, keymap) then
        return nil, "buffer mapping already exists: " .. keymap
    end

    local toggle_opts = { bufnr = bufnr }
    if opts.preset then
        toggle_opts.preset = opts.preset
    else
        toggle_opts.rules = vim.deepcopy(opts.rules)
    end
    local callback = function()
        local _, err = M.toggle(toggle_opts)
        if err then
            notify_error(err)
        end
    end

    vim.api.nvim_buf_create_user_command(bufnr, command, callback, {
        desc = "Toggle between test and source code",
    })
    if keymap then
        vim.keymap.set("n", keymap, callback, {
            buffer = bufnr,
            silent = true,
            desc = "Toggle between test and source code",
        })
    end
    attached[bufnr] = { command = command, keymap = keymap or nil }
    return true, nil
end

--- Attach the configured toggle for a buffer's filetype.
--- @param bufnr? integer
--- @return boolean? attached
--- @return string? error
function M.attach(bufnr)
    bufnr = bufnr or 0
    if bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return nil, "invalid buffer"
    end

    local opts = effective_options(vim.bo[bufnr].filetype)
    if not opts then
        return false, nil
    end
    return attach_with_options(bufnr, opts)
end

--- Configure filetype toggles and attach them automatically.
--- @param opts? { command?: string, keymap?: string|false, filetypes?: table<string, table> }
--- @return table config
function M.setup(opts)
    local resolved = resolve_config(opts)
    cleanup()
    config = resolved

    augroup = vim.api.nvim_create_augroup("test-toggle", { clear = true })
    local patterns = vim.tbl_keys(config.filetypes)
    table.sort(patterns)
    if #patterns > 0 then
        vim.api.nvim_create_autocmd("FileType", {
            group = augroup,
            pattern = patterns,
            callback = function(event)
                local _, err = M.attach(event.buf)
                if err then
                    notify_error(err)
                end
            end,
        })
    end
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = augroup,
        callback = function(event)
            attached[event.buf] = nil
        end,
    })

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            local opts_for_buffer = effective_options(vim.bo[bufnr].filetype)
            if opts_for_buffer then
                local _, err = attach_with_options(bufnr, opts_for_buffer)
                if err then
                    notify_error(err)
                end
            end
        end
    end
    return vim.deepcopy(config)
end

return M
