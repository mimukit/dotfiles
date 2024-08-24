-- INFO: Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- General improvements
vim.keymap.set("n", ";", ":", { desc = "CMD enter command mode" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Concat next line" })

vim.keymap.set("n", "n", "nzzzv", { desc = "Go to next search item and keep cursor in center of the screen" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Go to previous search item and keep cursor in center of the screen" })

-- Visual selection
vim.keymap.set("n", "<leader>vb", "ggVG", { desc = "Select whole file" })

-- Move cursor in insert mode
vim.keymap.set("i", "<M-j>", "<Down>", { desc = "Move cursor down" })
vim.keymap.set("i", "<M-k>", "<Up>", { desc = "Move cursor up" })
vim.keymap.set("i", "<M-h>", "<Left>", { desc = "Move cursor left" })
vim.keymap.set("i", "<M-l>", "<Right>", { desc = "Move cursor right" })

-- Exit terminal mode in the builtin terminal
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Navigator keymaps
vim.keymap.set({ "n", "t" }, "<C-h>", "<CMD>NavigatorLeft<CR>")
vim.keymap.set({ "n", "t" }, "<C-l>", "<CMD>NavigatorRight<CR>")
vim.keymap.set({ "n", "t" }, "<C-k>", "<CMD>NavigatorUp<CR>")
vim.keymap.set({ "n", "t" }, "<C-j>", "<CMD>NavigatorDown<CR>")

-- Split pane
vim.keymap.set("n", "<leader>uv", "<CMD>vsplit<CR>", { desc = "Split pane vertically" })

-- Clipboard management
vim.keymap.set({ "n", "v" }, "<leader>yy", [["+y]], { desc = "Copy to system clipboard" })
vim.keymap.set("n", "<leader>yl", [["+Y]], { desc = "Copy current line to clipboard" })
vim.keymap.set("n", "<leader>yb", "<cmd>%y+<CR>", { desc = "Copy whole file" })
vim.keymap.set("n", "<leader>yw", '"+yiw', { desc = "Copy word under cusror to the clipboard buffer" })
vim.keymap.set("n", "<leader>yW", '"+yiW', { desc = "Copy WORD under cusror to the clipboard buffer" })

vim.keymap.set({ "n", "v" }, "<leader>pp", [["+p]], { desc = "Paste from system clipboard" })
vim.keymap.set("x", "<leader>pr", [["_dP]], { desc = "Paste without modifying the buffer registry" })

vim.keymap.set(
  "n",
  "<leader>yp",
  ':let @+ = expand("%:p")<cr>:lua print("Copied path to: " .. vim.fn.expand("%:p"))<cr>',
  { silent = false, desc = "Copy current file path" }
)

-- External commands
vim.keymap.set("n", "cx", ":!chmod +x %<cr>", { desc = "Make file executable" })

-- Copilot
vim.keymap.set("n", "<leader>acp", "<cmd>Copilot panel<cr>", { desc = "Copilot panel" })
vim.keymap.set("n", "<leader>acs", "<cmd>Copilot status<cr>", { desc = "Copilot status" })
vim.keymap.set("n", "<leader>act", "<cmd>Copilot toggle<cr>", { desc = "Copilot toggle" })
