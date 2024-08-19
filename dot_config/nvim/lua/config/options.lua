-- INFO: [[ Setting options ]]
-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Set to true if you have a Nerd Font installed and selected in the terminal
vim.g.have_nerd_font = true

-- Separate neovim & system clipboard
vim.opt.clipboard = ""

-- Enable break indent
vim.opt.breakindent = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 20

-- Custom settings
vim.opt.wrap = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Fold unfold settings
vim.o.foldcolumn = "0" -- '0' is not bad
vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- Tab settings
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true
