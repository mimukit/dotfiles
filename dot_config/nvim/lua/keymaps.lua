-- INFO: [[ Basic Keymaps ]]
--
--  See `:help vim.keymap.set()`

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
-- vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
-- vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- NOTE: Disabled: because these functionalities are already provided by mini.basics plugin
--
-- vim.keymap.set('i', 'jk', '<ESC>', { desc = 'Alternative back to normal mode' })
-- vim.keymap.set({ 'n', 'v' }, '<leader>y', [["+y]], { desc = 'Copy to system clipboard' })
-- vim.keymap.set('n', '<leader>Y', [["+Y]], { desc = 'Copy current line to clipboard' })
-- vim.keymap.set({ 'n', 'v' }, '<leader>p', [["+p]], { desc = 'Paste from system clipboard' })
-- vim.keymap.set('n', '<CR>', 'O<Esc>j', { desc = 'Enter new line without insert mode' })
-- vim.keymap.set({ 'n', 'i', 'v' }, '<C-s>', '<cmd> w <cr>', { desc = 'Save current buffer' })
-- vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move line to down' })
-- vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move line to up' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Diagnostic keymaps
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

vim.keymap.set('n', '<Esc>', '<cmd>noh<CR>', { desc = 'Clear search highlights' })
vim.keymap.set('n', ';', ':', { desc = 'CMD enter command mode' })

vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Concat next line' })
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll down and keep cursor in center of the screen' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll up and keep cursor in center of the screen' })

vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Go to next search item and keep cursor in center of the screen' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Go to previous search item and keep cursor in center of the screen' })

vim.keymap.set('x', '<leader>p', [["_dP]], { desc = 'Paste without modifying the buffer registry' })

vim.keymap.set('n', '<C-c>', '<cmd>%y+<CR>', { desc = 'Copy whole file' })

vim.keymap.set('n', '<leader>tn', '<cmd>set nu!<CR>', { desc = '[T]oggle line [n]umber' })
vim.keymap.set('n', '<leader>trn', '<cmd>set rnu!<CR>', { desc = '[T]oggle [r]elative [n]umber' })
vim.keymap.set('n', '<leader>tc', '<cmd>Telescope colorscheme<CR>', { desc = '[T]oggle [c]olorscheme' })

-- Buffer management
vim.keymap.set({ 'n', 'v' }, '<leader>w', '<cmd> w <cr>', { desc = 'Save current buffer' })

vim.keymap.set('n', '<leader>bx', ':bd<CR>', { desc = 'Close current buffer' })
vim.keymap.set('n', '<leader>bn', ':bnext<CR>', { desc = 'Move to next buffer' })
vim.keymap.set('n', '<leader>bp', ':bprevious<CR>', { desc = 'Move to previous buffer' })

-- Oil file manager
vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open directory & file manager' })

-- TodoTelescope
vim.keymap.set('n', '<leader>st', ':TodoTelescope keywords=TODO,FIX,FIXME<CR>', { desc = 'Telescope list of todos' })

-- NeoTree
vim.keymap.set('n', '<leader>e', ':Neotree focus<CR>', { desc = 'Focus neotree file [e]xplorer' })
vim.keymap.set('n', '<leader>te', ':Neotree toggle<CR>', { desc = 'Focus neotree file [e]xplorer' })

-- Persistence
vim.keymap.set('n', '<leader>qs', function()
  require('persistence').load()
end, { desc = 'Load the session for the current directory' })
vim.keymap.set('n', '<leader>qS', function()
  require('persistence').select()
end, { desc = 'Select a session to load' })
vim.keymap.set('n', '<leader>ql', function()
  require('persistence').load { last = true }
end, { desc = 'Load the last session' })
vim.keymap.set('n', '<leader>qd', function()
  require('persistence').stop()
end, { desc = 'Stop Persistence => session wont be saved on exit' })

