--[[
Standard n-ary tree. Each tree node has an order and children.

local projects = {
    ['/home/mikatpt/harpoon'] = {
        finder = {
            marks = {
                order = nil,
                _c = {},
            },
        },
    },
}

_c = {
    "src" = {
        order = nil,
        _c = {
            "config" = {
                "nvim" =  { order = 1, _c = {}},
                "tmux" =  { order = 2, _c = {}}
            },
        }
    },
    "misc" = { order = 3, _c = {}},
}

Array = {
    { order = 1, path = 'src/config/nvim' },
    { order = 2, path = 'src/config/tmux'},
    { order = 3, path = 'misc'},
}
]]

local M = {}
local config = require('harpoon-finder').get_finder_config()

local function _traverse_and_flatten_tree(marks, root, path)
    if not root then return end

    if root.order ~= nil then
        table.insert(marks, { order = root.order, path = string.sub(path, 2) })
    end

    if not root._c then return end

    for child_name, child_node in pairs(root._c) do
        _traverse_and_flatten_tree(marks, child_node, path .. '/' .. child_name)
    end
end

-- Standard string split. DOESN'T WORK FOR ALL DELIMITERS.
local function _split(s, delimiter)
    local result = {}
    for match in (s .. delimiter):gmatch('(.-)' .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- Traverse the tree on each insert, adding nodes until we hit the leaf directory.
local function _traverse_and_add_dir(root, path, order)
    local n = root

    for _, dirname in pairs(_split(path, '/')) do
        -- If we find a dir which is already saved we should stop traversing; we're only interested in parent directories.
        if dirname == '' or n.order ~= nil then goto CONTINUE end

        if n._c[dirname] == nil then
            n._c[dirname] = { _c = {} }
        end
        n = n._c[dirname]
        ::CONTINUE::
    end

    n.order = order

    -- Remove children nodes if they exist; again, we only care about parent directories.
    n._c = { _c = {} }
end

local function _traverse_and_remove(root, path, dirname)
    if not root._c then return end

    for name, child in pairs(root._c) do
        local p = dirname .. '/' .. name
        if path == p then
            root._c[name] = nil
            return true
        end
        if _traverse_and_remove(child, path, p) then
            return true
        end
    end
    return false
end

-- Check if a directory exists in the tree. Optionally, remove it.
local function _exists_and_remove(root, path_to_check, dirname, remove)
    if not root._c then return false end

    for name, child in pairs(root._c) do
        local next_dir = dirname .. '/' .. name

        if path_to_check == next_dir then
            if remove then root._c[name] = nil end
            return true
        end

        if _exists_and_remove(child, path_to_check, next_dir, remove) then return true end
    end
    return false
end

-- Flattens tree into a sorted (ascending) array.
M.flatten_tree = function(root)
    local marks = {}

    -- If we add the root directory, short-circuit and only provide the '.' path.
    if root.order ~= nil then
        return { { order = root.order, path = '.' } }
    end

    _traverse_and_flatten_tree(marks, root, '')
    table.sort(marks, function(a, b)
        return a.order < b.order
    end)

    return marks
end

-- Iterates through given string array and builds a new tree using the given paths.
M.build_tree = function(marks)
    local root = { _c = {}, max = #marks, len = #marks }

    for index, path in pairs(marks) do
        if path == '.' then
            return { order = 1, _c = {}, max = 1, len = 1 }
        end
        _traverse_and_add_dir(root, path, index)
    end

    return root
end

-- Adds a single path to the tree.
M.add_path = function(root, path)
    if vim.fn.isdirectory(path) == 0 then return end

    if path == '.' then
        config.marks = { order = 1, _c = {}, max = 1, len = 1 }
        return
    end

    root.max = root.max + 1
    root.len = root.len + 1
    _traverse_and_add_dir(root, path, root.max)
end

-- Remove a single path from the tree, if it exists.
M.remove_path = function(root, path)
    if path == '.' then
        config.marks = { _c = {}, max = 0, len = 0 }
        return true
    end

    if _exists_and_remove(root, './' .. path, '.', true) then
        root.len = root.len - 1
        return true
    end
    return false
end

-- Check if a path is in the tree.
M.path_exists = function(root, path)
    if path == '.' then
        return root.order == 1
    end
    return _exists_and_remove(root, './' .. path, '.', false)
end

return M
