-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

vim.keymap.set("n", ";", ":", { desc = "CMD enter command mode" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Concat next line" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and keep cursor in center of the screen" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and keep cursor in center of the screen" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next search item and keep cursor in center of the screen" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous search item and keep cursor in center of the screen" })

vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without modifying the buffer registry" })

vim.keymap.set("n", "bv", "ggVG", { desc = "Select whole file" })
vim.keymap.set("n", "by", "<cmd>%y+<CR>", { desc = "Copy whole file" })

-- Buffer management
vim.keymap.set({ "n", "v" }, "<leader>w", "<cmd> w <cr>", { desc = "Save current buffer" })
vim.keymap.set("n", "<leader>bx", ":bd<CR>", { desc = "Close current buffer" })
vim.keymap.set("n", "<leader>bd", ":bufdo bd<CR>", { desc = "Close all buffers" })
vim.keymap.set("n", "<leader>bn", ":bnext<CR>", { desc = "Move to next buffer" })
vim.keymap.set("n", "<leader>bp", ":bprevious<CR>", { desc = "Move to previous buffer" })

-- Navigator
vim.keymap.set({ "n", "t" }, "<C-h>", "<CMD>NavigatorLeft<CR>")
vim.keymap.set({ "n", "t" }, "<C-l>", "<CMD>NavigatorRight<CR>")
vim.keymap.set({ "n", "t" }, "<C-k>", "<CMD>NavigatorUp<CR>")
vim.keymap.set({ "n", "t" }, "<C-j>", "<CMD>NavigatorDown<CR>")
