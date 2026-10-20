-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

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
vim.opt.conceallevel = 0
vim.opt.cmdheight = 0

-- Disable unused remote plugin providers
vim.g.loaded_python3_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
