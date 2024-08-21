return {
  {
    "folke/which-key.nvim",
    opts = {
      defaults = {},
      win = {
        no_overlap = false,
        border = "rounded",
        title = false,
      },
      spec = {
        {
          mode = { "n", "v" },
          { "<leader><tab>", group = "tabs" },
          { "<leader>c", group = "code" },
          { "<leader>f", group = "file/find" },
          { "<leader>g", group = "git" },
          { "<leader>gh", group = "hunks" },
          { "<leader>q", group = "quit/session" },
          { "<leader>s", group = "search" },
          { "<leader>u", group = "ui", icon = { icon = "󰙵 ", color = "cyan" } },
          { "<leader>x", group = "diagnostics/quickfix", icon = { icon = "󱖫 ", color = "green" } },
          { "[", group = "prev" },
          { "]", group = "next" },
          { "g", group = "goto" },
          { "gs", group = "surround" },
          { "z", group = "fold" },
          {
            "<leader>b",
            group = "buffer",
            expand = function()
              return require("which-key.extras").expand.buf()
            end,
          },
          {
            "<leader>w",
            group = "windows",
            proxy = "<c-w>",
            expand = function()
              return require("which-key.extras").expand.win()
            end,
          },
          { "gx", desc = "Open with system app" },
          { "<leader>y", group = "yank modifiers", icon = { icon = "© ", color = "cyan" } },
          { "<leader>p", group = "put modifiers", icon = { icon = "℗ ", color = "cyan" } },
          { "<leader>v", group = "visual modifiers", icon = { icon = "⊹ ", color = "yellow" } },
        },
      },
    },
  },
}
