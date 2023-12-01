local harpoon = require('harpoon')
local telescope = require('telescope.builtin')
local popup = require('plenary.popup')
local log = require('harpoon.dev').log
local tree = require('harpoon-finder.tree')
local config = require('harpoon-finder').get_finder_config()

local M = {}

Harpoon_win_id = nil
Harpoon_bufh = nil

local function get_menu_items()
    log.trace('_get_menu_items()')
    local lines = vim.api.nvim_buf_get_lines(Harpoon_bufh, 0, -1, true)
    local indices = {}

    for idx = 1, #lines do
        local space_location = string.find(lines[idx], ' ')
        log.debug('_get_menu_items():', idx, space_location)

        if space_location ~= nil then
            local path = string.sub(lines[idx], space_location + 1)
            if vim.fn.isdirectory(path) == 1 then
                table.insert(indices, path)
            else
                error(path .. ' is an invalid path! Discarding edits.')
                log.debug(path .. ' is an invalid path! Discarding edits.')
            end
        end
    end

    return indices
end

local function close_menu(force_save)
    force_save = force_save or false
    local global_config = harpoon.get_global_settings()

    if global_config.save_on_toggle or force_save then
        local ok, items = pcall(get_menu_items)
        if not ok then
            vim.notify('harpoon-finder: invalid path! discarding edits', vim.log.levels.WARN)
        else
            config.marks = tree.build_tree(items)
        end
    end

    vim.api.nvim_win_close(Harpoon_win_id, true)

    Harpoon_win_id = nil
    Harpoon_bufh = nil
end

local function create_window()
    log.trace('_create_window()')
    local menu_config = harpoon.get_menu_config()
    local width = menu_config.width or 60
    local height = menu_config.height or 10
    local borderchars = menu_config.borderchars or { '─', '│', '─', '│', '╭', '╮', '╯', '╰' }
    local bufnr = vim.api.nvim_create_buf(false, false)

    local Harpoon_win_id, win = popup.create(bufnr, {
        title = 'Harpoon Finder',
        highlight = 'HarpoonWindow',
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars,
    })

    vim.api.nvim_win_set_option(win.border.win_id, 'winhl', 'Normal:HarpoonBorder')

    return {
        bufnr = bufnr,
        win_id = Harpoon_win_id,
    }
end

M.toggle_quick_menu = function()
    log.trace('toggle_quick_menu()')
    if Harpoon_win_id ~= nil and vim.api.nvim_win_is_valid(Harpoon_win_id) then
        close_menu(true)
        return
    end

    local win_info = create_window()
    local contents = {}
    local global_config = harpoon.get_global_settings()

    Harpoon_win_id = win_info.win_id
    Harpoon_bufh = win_info.bufnr

    local items = tree.flatten_tree(config.marks)
    for idx, item in pairs(items) do
        contents[idx] = string.format('%d %s', idx, item.path)
    end

    vim.api.nvim_buf_set_name(Harpoon_bufh, 'harpoon-menu')
    vim.api.nvim_buf_set_lines(Harpoon_bufh, 0, #contents, false, contents)
    vim.api.nvim_buf_set_option(Harpoon_bufh, 'filetype', 'harpoon')
    vim.api.nvim_buf_set_option(Harpoon_bufh, 'buftype', 'acwrite')
    vim.api.nvim_buf_set_option(Harpoon_bufh, 'bufhidden', 'delete')
    vim.api.nvim_buf_set_keymap(
        Harpoon_bufh,
        'n',
        'q',
        ":lua require('harpoon-finder.ui').toggle_quick_menu()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Harpoon_bufh,
        'n',
        '<ESC>',
        ":lua require('harpoon-finder.ui').toggle_quick_menu()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Harpoon_bufh,
        'n',
        '<CR>',
        ":lua require('harpoon-finder.ui').select_menu_item()<CR>",
        {}
    )
    vim.cmd(
        string.format("autocmd BufWriteCmd <buffer=%s> :lua require('harpoon-finder.ui').on_menu_save()", Harpoon_bufh)
    )
    if global_config.save_on_change then
        vim.cmd(
            string.format(
                "autocmd TextChanged,TextChangedI <buffer=%s> :lua require('harpoon-finder.ui').on_menu_save()",
                Harpoon_bufh
            )
        )
    end
    vim.cmd(string.format('autocmd BufModifiedSet <buffer=%s> set nomodified', Harpoon_bufh))
    vim.cmd("autocmd BufLeave <buffer> ++nested ++once :silent lua require('harpoon-finder.ui').toggle_quick_menu()")
end

M.select_menu_item = function()
    close_menu(true)
    M.find_files()
end

M.get_search_dirs = function()
    local dirs = {}
    local items = tree.flatten_tree(config.marks)
    for _, item in pairs(items) do
        table.insert(dirs, item.path)
    end
    return dirs
end

M.find_files = function(opts)
    opts = opts or {}
    opts.prompt_title = 'Harpoon Finder'
    opts.search_dirs = M.get_search_dirs()
    opts.hidden = true

    telescope.find_files(opts)
end

M.on_menu_save = function()
    log.trace('on_menu_save()')
    local ok, items = pcall(get_menu_items)
    if not ok then
        return
    end

    config.marks = tree.build_tree(items)
end

function M.location_window(options)
    local default_options = {
        relative = 'editor',
        style = 'minimal',
        width = 30,
        height = 15,
        row = 2,
        col = 2,
    }
    options = vim.tbl_extend('keep', options, default_options)

    local bufnr = options.bufnr or vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, options)

    return {
        bufnr = bufnr,
        win_id = win_id,
    }
end

function M.notification(text)
    local win_stats = vim.api.nvim_list_uis()[1]
    local win_width = win_stats.width

    local prev_win = vim.api.nvim_get_current_win()

    local info = M.location_window({
        width = 20,
        height = 2,
        row = 1,
        col = win_width - 21,
    })

    vim.api.nvim_buf_set_lines(info.bufnr, 0, 5, false, { '!!! Notification', text })
    vim.api.nvim_set_current_win(prev_win)

    return {
        bufnr = info.bufnr,
        win_id = info.win_id,
    }
end

function M.close_notification(bufnr)
    vim.api.nvim_buf_delete(bufnr)
end

return M
