return {
  {
    'j-hui/fidget.nvim',
    lazy = false,
    opts = {
      progress = {
        poll_rate = 0,
        display = {
          progress_icon = { pattern = 'dots', period = 3 },
        },
      },
      notification = {
        poll_rate = 100,
        window = {
          winblend = 0,
        },
      },
    },
  },
}
