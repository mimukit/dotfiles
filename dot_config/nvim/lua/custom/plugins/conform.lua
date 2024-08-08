return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>fm',
        function()
          require('conform').format { async = true, lsp_fallback = true }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = true,
      format_on_save = function(bufnr)
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        return {
          timeout_ms = 1000,
          lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
        }
      end,
      formatters_by_ft = {
        css = { 'prettier' },
        graphql = { 'prettier' },
        html = { 'prettier' },
        -- You can use 'stop_after_first' to run the first available formatter from the list
        javascript = { 'prettier', stop_after_first = true },
        javascriptreact = { 'prettier' },
        json = { 'prettier' },
        liquid = { 'prettier' },
        lua = { 'stylua' },
        markdown = { 'prettier' },
        -- Conform can also run multiple formatters sequentially
        python = { 'isort', 'black' },
        typescript = { 'prettier' },
        typescriptreact = { 'prettier' },
        yaml = { 'prettier' },
      },
    },
  },
}
