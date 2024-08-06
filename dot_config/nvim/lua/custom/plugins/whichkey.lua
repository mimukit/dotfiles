return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      local wk = require 'which-key'

      require('which-key').setup()

      -- Document existing key chains
      wk.add {
        { '<leader>c', group = '[C]ode' },
        { '<leader>d', group = '[D]ocument' },
        { '<leader>r', group = '[R]ename' },
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
        { '<leader>W', group = '[W]orkspace' },
        { '<leader>l', group = 'Lazygit + Lspsaga' },
      }

      wk.add {
        { '<leader>ll', group = 'Lspsaga' },
        {
          mode = { 'n' },
          { '<leader>llc', '<cmd>Lspsaga code_action<cr>', desc = 'Code action' },
          { '<leader>llo', '<cmd>Lspsaga outline<cr>', desc = 'Outline' },
          { '<leader>llr', '<cmd>Lspsaga rename<cr>', desc = 'Rename' },
          { '<leader>lld', '<cmd>Lspsaga goto_definition<cr>', desc = 'Lsp goto definition' },
          { '<leader>llf', '<cmd>Lspsaga finder<cr>', desc = 'Lsp Finder' },
          { '<leader>llp', '<cmd>Lspsaga preview_definition<cr>', desc = 'Preview definition' },
          { '<leader>lls', '<cmd>Lspsaga signature_help<cr>', desc = 'Signature help' },
          { '<leader>llw', '<cmd>Lspsaga show_workspace_diagnostics<cr>', desc = 'Show workspace diagnostics' },
        },
      }
    end,
  },
}
