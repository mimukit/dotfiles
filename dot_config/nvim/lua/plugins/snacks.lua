return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            layout = {
              layout = {
                position = "right", -- Moves the explorer to the right side
              },
            },
          },
          files = {
            hidden = true, -- Shows hidden files (like .env)
            ignored = true, -- Shows gitignored files
          },
        },
      },
    },
  },
}
