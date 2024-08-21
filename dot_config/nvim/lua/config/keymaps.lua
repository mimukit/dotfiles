-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

vim.keymap.set("n", ";", ":", { desc = "CMD enter command mode" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Concat next line" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next search item and keep cursor in center of the screen" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous search item and keep cursor in center of the screen" })

vim.keymap.set("n", "<leader>bv", "ggVG", { desc = "Select whole file" })
vim.keymap.set("n", "<leader>by", "<cmd>%y+<CR>", { desc = "Copy whole file" })

-- vim.keymap.set({ "n", "v" }, "<leader>w", "<cmd> w <cr>", { desc = "Save current buffer" })
-- Move cursor in insert mode
vim.keymap.set("i", "<M-j>", "<Down>", { desc = "Move cursor down" })
vim.keymap.set("i", "<M-k>", "<Up>", { desc = "Move cursor up" })
vim.keymap.set("i", "<M-h>", "<Left>", { desc = "Move cursor left" })
vim.keymap.set("i", "<M-l>", "<Right>", { desc = "Move cursor right" })

-- Navigator
vim.keymap.set({ "n", "t" }, "<C-h>", "<CMD>NavigatorLeft<CR>")
vim.keymap.set({ "n", "t" }, "<C-l>", "<CMD>NavigatorRight<CR>")
vim.keymap.set({ "n", "t" }, "<C-k>", "<CMD>NavigatorUp<CR>")
vim.keymap.set({ "n", "t" }, "<C-j>", "<CMD>NavigatorDown<CR>")

-- Split pane
vim.keymap.set("n", "<leader>uv", "<CMD>vsplit<CR>", { desc = "Split pane vertically" })

-- System Clipboard
vim.keymap.set({ "n", "v" }, "<leader>cy", [["+y]], { desc = "Copy to system clipboard" })
vim.keymap.set("n", "<leader>cY", [["+Y]], { desc = "Copy current line to clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>cp", [["+p]], { desc = "Paste from system clipboard" })

-- Telescope extensions
vim.keymap.set("n", "<leader>sB", function()
  require("telescope").extensions.file_browser.file_browser({
    path = vim.fn.expand("%:p:h"),
    select_buffer = true,
  })
end, { desc = "Telescope file browser" })
