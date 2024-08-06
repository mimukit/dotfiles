return {
  {
    'ThePrimeagen/harpoon',
    event = 'VeryLazy',
    branch = 'harpoon2',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
    enabled = true,
    opts = {
      menu = {
        width = vim.api.nvim_win_get_width(0) - 4,
      },
      settings = {
        save_on_toggle = true,
      },
    },
    -- stylua: ignore
    keys = {
      { '<leader>ha', function() require('harpoon'):list():add() end, desc = 'Add location' },
      { '<leader>hn', function() require('harpoon'):list():next() end, desc = 'Next location' },
      { '<leader>hp', function() require('harpoon'):list():prev() end, desc = 'Previous location' },
      { '<leader>hd', function() require('harpoon'):list():remove() end, desc = 'Delete location' },
      { '<leader>h1', function() require('harpoon'):list():select(1) end, desc = 'Harpoon to File 1' },
      { '<leader>h2', function() require('harpoon'):list():select(2) end, desc = 'Harpoon to File 2' },
      { '<leader>h3', function() require('harpoon'):list():select(3) end, desc = 'Harpoon to File 3' },
      { '<leader>h4', function() require('harpoon'):list():select(4) end, desc = 'Harpoon to File 4' },
      { '<leader>h5', function() require('harpoon'):list():select(5) end, desc = 'Harpoon to File 5' },
      { '<leader>hl', function()
          local harpoon = require('harpoon')
              harpoon.ui:toggle_quick_menu(harpoon:list())
	  end, desc = 'List locations' },
    },
  },
}
