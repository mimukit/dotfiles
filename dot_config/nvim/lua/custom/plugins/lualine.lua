return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      local colors = {
        black = '#080808',
        blue = '#89b4fa',
        green = '#a6e3a1',
        mauve = '#cba6f7',
        peach = '#fab387',
        surface = '#313244',
        red = '#f38ba8',
        white = '#cdd6f4',
      }

      local catppuccin_custom = {
        normal = {
          a = { fg = colors.black, bg = colors.peach },
          b = { fg = colors.white, bg = colors.surface },
          c = { fg = colors.white },

          -- x = { fg = colors.white },
          -- y = { fg = colors.white, bg = colors.surface },
          -- z = { fg = colors.black, bg = colors.peach },
        },

        insert = { a = { fg = colors.black, bg = colors.green } },
        visual = { a = { fg = colors.black, bg = colors.blue } },
        replace = { a = { fg = colors.black, bg = colors.red } },
        command = { a = { fg = colors.black, bg = colors.mauve } },

        inactive = {
          a = { fg = colors.white, bg = colors.surface },
          b = { fg = colors.white, bg = colors.surface },
          c = { fg = colors.white },
        },
      }

      require('lualine').setup {
        options = {
          theme = catppuccin_custom,
          -- theme = 'catppuccin', -- 'auto', 'catppuccin'
          icons_enabled = true,
          component_separators = '',
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          section_separators = { left = '', right = '' },
          ignore_focus = {},
          always_divide_middle = false,
          globalstatus = false,
          refresh = {
            statusline = 1000,
            tabline = 1000,
            winbar = 1000,
          },
        },
        sections = {
          lualine_a = { { 'mode', separator = { left = '' }, right_padding = 0 } },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = {
            '%=',
            'filename',
          },
          lualine_x = {},
          lualine_y = { 'filetype' },
          lualine_z = {
            { 'location', separator = { right = '|' } },
            { 'progress', separator = { right = '' }, left_padding = 0 },
          },
        },
        inactive_sections = {
          lualine_a = { 'filename' },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = { 'location' },
        },
        tabline = {},
        extensions = { 'neo-tree' },
      }
    end,
  },
}
