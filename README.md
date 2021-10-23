# Harpoon Finder

## Summary

This is a simple extension of harpoon's functionality which enables use of harpoon's API to
save directories for use in Telescope.


In large monorepos, Telescope can potentially become unwieldy. This isn't due to performance
issues - rather, if your repository has lots of projects within it with similar structure,
there can be lots of files with duplicate names.


In short; mark folders with harpoon, search those folders with Telescope.


## Installation

### Prerequisites
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

Using [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use({ 'ThePrimeagen/harpoon', requires = { 'nvim-lua/plenary.nvim', 'nvim-lua/popup.nvim' } })
use({ 'mikatpt/harpoon-finder', after = 'harpoon' })
```
Using [vim-plug](https://github.com/junegunn/vim-plug)

```viml
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/popup.nvim'
Plug 'ThePrimeagen/harpoon'
Plug 'mikatpt/harpoon-finder'
```

## Usage

### Marking

From within a file, call the following function to mark or remove its parent directory.
```lua
require('harpoon-finder.mark').toggle_dir()
```

### Quick Menu
Paths may be viewed and modified in the quick menu. Invalid paths will be
ignored, and child directories will be truncated into their parent directories.
```lua
require('harpoon-finder.ui').toggle_quick_menu()
```

### Search with Telescope
For convenience, a `find_files` method is provided below.
```lua
require('harpoon-finder.ui').find_files()
```
However, you can also use the `get_search_dirs` method in conjunction with
Telescope's builtin methods directly.
```lua
local dirs = require('harpoon-finder.ui').get_search_dirs()
require('telescope.builtin').find_files({ search_dirs = dirs })
require('telescope.builtin').live_grep({ search_dirs = dirs })
```
