local harpoon = require('harpoon')
local finder = require('harpoon-finder')
local log = require('harpoon.dev').log
local tree = require('harpoon-finder.tree')
local tree_root = finder.get_finder_config().marks
local utils = require('harpoon-finder.utils')

local M = {}
local callbacks = {}

local function emit_changed()
    log.trace('_emit_changed()')
    if harpoon.get_global_settings().save_on_change then
        harpoon.save()
    end

    if not callbacks['changed'] then
        log.trace("_emit_changed(): no callbacks for 'changed', returning")
        return
    end

    for idx, cb in pairs(callbacks['changed']) do
        log.trace(string.format("_emit_changed(): Running callback #%d for 'changed'", idx))
        cb()
    end
end

local function get_dir_from_name(fileOrDir)
    if vim.fn.isdirectory(fileOrDir) == 1 or fileOrDir == '.' then
        return fileOrDir
    end

    for idx = #fileOrDir, 1, -1 do
        local char = string.sub(fileOrDir, idx, idx)
        if char == '/' then
            local dir = string.sub(fileOrDir, 1, idx - 1)
            return dir
        end
    end

    return ''
end

local function get_buf_name(id)
    log.trace('_get_buf_name():', id)
    if id == nil then
        return utils.normalize_path(get_dir_from_name(vim.api.nvim_buf_get_name(0)))
    elseif type(id) == 'string' then
        return utils.normalize_path(get_dir_from_name(id))
    end

    return ''
end

local function create_mark(path)
    log.trace(string.format('_create_mark(): Creating mark for folder %s', path))
    tree.add_path(tree_root, path)
end

local function mark_exists(buf_name)
    log.trace('_mark_exists()')
    if tree.path_exists(tree_root, buf_name) then
        log.debug('_mark_exists(): Mark exists', buf_name)
        return true
    end

    log.debug("_mark_exists(): Mark doesn't exist", buf_name)
    return false
end

local function validate_buf_name(buf_name)
    log.trace('_validate_buf_name():', buf_name)
    if buf_name == '' or buf_name == nil then
        log.error('_validate_buf_name(): Not a valid name for a mark,', buf_name)
        error("Couldn't find a valid file name to mark, sorry.")
        return
    end
end

M.add_dir = function(dir_name_or_buf_id)
    local buf_name = get_buf_name(dir_name_or_buf_id)
    log.trace('add_file():', buf_name)

    validate_buf_name(buf_name)
    create_mark(buf_name)
    emit_changed()
end

M.rm_dir = function(dir_name_or_buf_id)
    local buf_name = get_buf_name(dir_name_or_buf_id)
    local was_removed = tree.remove_path(tree_root, buf_name)
    log.trace('rm_file(): Removing mark for folder ', buf_name)

    if was_removed then
        emit_changed()
    end
end

M.toggle_dir = function(dir_name_or_buf_id)
    local buf_name = get_buf_name(dir_name_or_buf_id)
    log.trace('toggle_file():', buf_name)

    validate_buf_name(buf_name)

    if mark_exists(buf_name) then
        M.rm_dir(buf_name)
        print('Harpoon Finder: Mark removed')
        log.debug('toggle_file(): Mark removed')
    else
        M.add_dir(buf_name)
        print('Harpoon Finder: Mark added')
        log.debug('toggle_file(): Mark added')
    end
end

M.on = function(event, cb)
    log.trace('on():', event)
    if not callbacks[event] then
        log.debug('on(): no callbacks yet for', event)
        callbacks[event] = {}
    end

    table.insert(callbacks[event], cb)
    log.debug('on(): All callbacks:', callbacks)
end

return M
