return {
  {
    "williamboman/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
        height = 0.8,
      },
      ensure_installed = {
        -- snippets
        "emmet-language-server",
      },
    },
  },
}
