-- INFO: Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Add any additional autocmds here

-- INFO: Customize LSP Info UI window border
local function set_lsp_info_ui_border()
  require("lspconfig.ui.windows").default_options.border = "rounded"
end

-- Create an auto command to set the border when LSP attaches
vim.api.nvim_create_autocmd("LspAttach", {
  callback = set_lsp_info_ui_border,
})

-- INFO: Disable diagnostics for .env files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.env",
  callback = function()
    vim.diagnostic.enable(false)
  end,
})
