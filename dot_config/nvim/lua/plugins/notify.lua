return {
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    opts = {
      render = "minimal", -- default, compact, minimal, simple
      stages = "fade_in_slide_out", -- fade, fade_in_slide_out, slide, static
      timeout = 500,
      top_down = true,
    },
  },
}
