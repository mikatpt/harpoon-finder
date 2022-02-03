-- stylua: ignore start
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

    for _, dirname in ipairs(_split(path, '/')) do
        -- If we find a dir which is already saved we should stop traversing; we're only interested in parent directories.
        if dirname == '' or n.order ~= nil then break end

        if n._c[dirname] == nil then
            n._c[dirname] = { _c = {} }
        end
        n = n._c[dirname]
    end

    n.order = order

    -- Remove children nodes if they exist; again, we only care about parent directories.
    n._c = { _c = {} }
end

-- Check if a directory exists in the tree. Optionally, remove it.
local function _exists_and_remove(root, path_to_check, remove)
    if not root._c then return false end

    local node = root

    for _, child_name in ipairs(_split(path_to_check, '/')) do
        local next_child = node._c[child_name]
        if not next_child then return false end

        if next_child.order ~= nil then
            if remove then node._c[child_name] = nil end
            return true
        end
        node = next_child
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
    local root = { _c = {}, max = #marks }

    for index, path in pairs(marks) do
        if path == '.' then
            return { order = 1, _c = {}, max = 1 }
        end
        _traverse_and_add_dir(root, path, index)
    end

    return root
end

-- Adds a single path to the tree.
M.add_path = function(root, path)
    if vim.fn.isdirectory(path) == 0 then return end

    if path == '.' then
        config.marks = { order = 1, _c = {}, max = 1 }
        return
    end

    root.max = root.max + 1
    _traverse_and_add_dir(root, path, root.max)
end

-- Remove a single path from the tree, if it exists.
M.remove_path = function(root, path)
    if path == '.' then
        config.marks = { _c = {}, max = 0 }
        return true
    end

    if _exists_and_remove(root, path, true) then return true end
    return false
end

-- Check if a path is in the tree.
M.path_exists = function(root, path)
    if path == '.' then return root.order == 1 end
    return _exists_and_remove(root, path, false)
end

return M
