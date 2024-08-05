return {
  { -- Collection of various small independent plugins/modules
    'echasnovski/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      --
      -- Examples:
      --  - va)  - [V]isually select [A]round [)]paren
      --  - yinq - [Y]ank [I]nside [N]ext [Q]uote
      --  - ci'  - [C]hange [I]nside [']quote
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings (brackets, quotes, etc.)
      --
      -- - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
      -- - sd'   - [S]urround [D]elete [']quotes
      -- - sr)'  - [S]urround [R]eplace [)] [']
      require('mini.surround').setup()

      -- Animate common Neovim actions
      require('mini.animate').setup {
        open = {
          enable = false,
        },
        close = {
          enable = false,
        },
      }

      -- Comment lines
      --
      -- Examples:
      -- - gc - Toggle comment (like `gcip` - comment inner paragraph)
      -- - gcc - Toggle comment on current lines
      -- - dgc - Delete whole comment block
      require('mini.comment').setup()

      -- Enable basic improvements
      require('mini.basics').setup {
        -- Options. Set to `false` to disable.
        options = {
          -- Basic options ('number', 'ignorecase', and many more)
          basic = true,

          -- Extra UI features ('winblend', 'cmdheight=0', ...)
          extra_ui = false,

          -- Presets for window borders ('single', 'double', ...)
          win_borders = 'dot',
        },

        -- Mappings. Set to `false` to disable.
        mappings = {
          -- Basic mappings (better 'jk', save with Ctrl+S, ...)
          basic = true,

          -- Prefix for mappings that toggle common options ('wrap', 'spell', ...).
          -- Supply empty string to not create these mappings.
          option_toggle_prefix = [[\]],

          -- Window navigation with <C-hjkl>, resize with <C-arrow>
          windows = true,

          -- Move cursor in Insert, Command, and Terminal mode with <M-hjkl>
          move_with_alt = true,
        },

        -- Autocommands. Set to `false` to disable
        autocommands = {
          -- Basic autocommands (highlight on yank, start Insert in terminal, ...)
          basic = true,

          -- Set 'relativenumber' only in linewise and blockwise Visual mode
          relnum_in_visual_mode = false,
        },

        -- Whether to disable showing non-error feedback
        silent = false,
      }

      -- ... and there is more!
      --  Check out: https://github.com/echasnovski/mini.nvim
    end,
  },
}
