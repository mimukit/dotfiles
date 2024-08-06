return {
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    version = '*',
    dependencies = 'nvim-tree/nvim-web-devicons',

    config = function()
      require('bufferline').setup {

        options = {
          -- "slant" | "slope" | "thick" | "thin" | { 'any', 'any' },
          separator_style = 'thick',

          offsets = {
            {
              filetype = 'neo-tree',
              text = 'File Explorer',
              highlight = 'Directory',
              separator = true, -- use a "true" to enable the default, or set your own character
            },
          },

          highlights = require('catppuccin.groups.integrations.bufferline').get {
            styles = { 'italic', 'bold' },
          },
        },
      }
    end,
  },
}
