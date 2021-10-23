local utils = require('harpoon-finder.utils')

local M = {}

HarpoonConfig = HarpoonConfig or {}

M.get_finder_config = function()
    return utils.ensure_correct_config(HarpoonConfig).projects[vim.loop.cwd()].finder
end

-- This should do nothing except setup the finder marks table.
M.setup = function(config)
    config = config or {}
    local complete_config = utils.merge_tables(HarpoonConfig, config)

    utils.ensure_correct_config(complete_config)
    HarpoonConfig = complete_config
end

M.setup()
return M
