return {
  {
    'nvim-pack/nvim-spectre',
    opts = {
      open_cmd = 'noswapfile vnew',
      mapping = {
        ['toggle_gitignore'] = {
          map = 'tg',
          cmd = "<cmd>lua require('spectre').change_options('gitignore')<CR>",
          desc = 'toggle gitignore',
        },
      },
      find_engine = {
        ['rg'] = {
          cmd = 'rg',
          args = {
            '--pcre2',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--ignore',
          },
          options = {
            ['gitignore'] = {
              value = '--no-ignore',
              icon = '[G]',
              desc = 'gitignore',
            },
          },
        },
      },
      default = {
        find = {
          cmd = 'rg',
          options = { 'ignore-case', 'hidden', 'gitignore' },
        },
      },
    },
  },
}
