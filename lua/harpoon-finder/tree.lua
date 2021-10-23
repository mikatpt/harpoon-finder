--[[
Standard n-ary tree. Each tree node has an order and children.

local projects = {
    ['/home/mikatpt/harpoon'] = {
        finder = {
            marks = {
                order = nil,
                children = {},
            },
        },
    },
}

children = {
    "src" = {
        order = nil,
        children = {
            "config" = {
                "nvim" =  { order = 1, children = {}},
                "tmux" =  { order = 2, children = {}}
            },
        }
    },
    "misc" = { order = 3, children = {}},
}

Array = {
    { order = 1, path = 'src/config/nvim' },
    { order = 2, path = 'src/config/tmux'},
    { order = 3, path = 'misc'},
}
]]

local M = {}

local function _traverse_and_flatten_tree(marks, root, path)
    if not root then return end

    if root.order ~= nil then
        table.insert(marks, { order = root.order, path = string.sub(path, 2) })
    end

    if not root.children then return end

    for child_name, child_node in pairs(root.children) do
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

        if n.children[dirname] == nil then
            n.children[dirname] = { children = {} }
        end
        n = n.children[dirname]
        ::CONTINUE::
    end

    n.order = order

    -- Remove children nodes if they exist; again, we only care about parent directories.
    n.children = { children = {} }
end

local function _traverse_and_remove(root, path, dirname)
    if not root.children then return end
    for name, child in pairs(root.children) do
        local p = dirname .. '/' .. name
        if path == p then
            root.children[name] = nil
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
    if not root.children then return false end
    for name, child in pairs(root.children) do
        local next_dir = dirname .. '/' .. name

        if path_to_check == next_dir then
            if remove then root.children[name] = nil end
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
    if marks and marks[1] == '.' then
        return { ['.'] = { order = 1, children = {}, max = 1, len = 1 } }
    end

    local root = { children = {}, max = #marks, len = #marks }

    for index, path in pairs(marks) do
        _traverse_and_add_dir(root, path, index)
    end

    return root
end

-- Adds a single path to the tree.
M.add_path = function(root, path)
    if vim.fn.isdirectory(path) == 0 then return end
    root.max = root.max + 1
    root.len = root.len + 1
    _traverse_and_add_dir(root, path, root.max)
end

-- Remove a single path from the tree, if it exists.
M.remove_path = function(root, path)
    if path == '.' then
        root = { children = {} }
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
    if path == '.' then return true end
    return _exists_and_remove(root, './' .. path, '.', false)
end

return M
