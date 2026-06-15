-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- General improvements
vim.keymap.set("n", ";", ":", { desc = "CMD enter command mode" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next search item and keep cursor in center of the screen" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous search item and keep cursor in center of the screen" })

-- Navigator keymaps
vim.keymap.set({ "n", "t" }, "<C-h>", "<CMD>NavigatorLeft<CR>")
vim.keymap.set({ "n", "t" }, "<C-l>", "<CMD>NavigatorRight<CR>")
vim.keymap.set({ "n", "t" }, "<C-k>", "<CMD>NavigatorUp<CR>")
vim.keymap.set({ "n", "t" }, "<C-j>", "<CMD>NavigatorDown<CR>")

-- Clipboard management
vim.keymap.set("n", "<leader>yb", "<cmd>%y+<CR>", { desc = "Copy whole file" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Copy selection to system clipboard" })
vim.keymap.set("n", "<leader>yy", '"+yy', { desc = "Copy line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste from system clipboard" })
