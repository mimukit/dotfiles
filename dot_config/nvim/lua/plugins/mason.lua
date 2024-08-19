return {
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- formatters
        "black",
        "isort",
        "prettierd",
        "shfmt",
        "stylua",

        -- linters
        "eslint_d",
        "hadolint",
        "jsonlint",
        "markdownlint",
        "pylint",

        -- snippets
        "emmet-language-server",
      },
    },
  },
}
