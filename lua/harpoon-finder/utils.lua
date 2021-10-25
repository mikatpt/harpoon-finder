local Path = require('plenary.path')
local M = {}

local function merge_table_impl(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == 'table' then
            if type(t1[k]) == 'table' then
                merge_table_impl(t1[k], v)
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
end

M.merge_tables = function(...)
    local out = {}
    for i = 1, select('#', ...) do
        merge_table_impl(out, select(i, ...))
    end
    return out
end

M.normalize_path = function(item)
    return Path:new(item):make_relative(vim.loop.cwd())
end

-- This should only set up folder for finder marks.
M.ensure_correct_config = function(config)
    local projects = config.projects
    if projects[vim.loop.cwd()] == nil then
        projects[vim.loop.cwd()] = {
            mark = {
                marks = {},
            },
            term = {
                cmds = {},
            },
            finder = {
                marks = { _c = {}, max = 0 },
            },
        }
    end

    local proj = projects[vim.loop.cwd()]

    if proj.finder == nil then
        proj.finder = { marks = { _c = {}, max = 0 } }
    end

    return config
end

return M
