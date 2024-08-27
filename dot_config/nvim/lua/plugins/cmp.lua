return {
  {
    "hrsh7th/nvim-cmp",
    opts = {
      window = {
        completion = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
        documentation = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
      },
      -- Set view to follow cursor while typing
      view = {
        entries = {
          follow_cursor = true,
        },
      },
      -- performance
      performance = {
        debounce = 0, -- default is 60ms
        throttle = 0, -- default is 30ms
      },
    },
  },
}
