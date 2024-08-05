return {

  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        dockerfile = { 'hadolint' },
        json = { 'jsonlint' },
        javascript = { 'eslint_d' },
        javascriptreact = { 'eslint_d' },
        markdown = { 'markdownlint' },
        python = { 'pylint' },
        typescript = { 'eslint_d' },
        typescriptreact = { 'eslint_d' },
      }

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          lint.try_lint()
        end,
      })
    end,
  },
}
