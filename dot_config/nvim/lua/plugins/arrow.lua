return {
  "otavioschwanck/arrow.nvim",
  event = "VeryLazy",
  opts = {
    leader_key = "-",
    buffer_leader_key = "m",

    show_icons = true,
    separate_by_branch = false,
    always_show_path = false,
    per_buffer_config = {
      lines = 2,
      sort_automatically = true,
    },

    window = {
      width = 100,
      height = 20,
      row = 10,
      col = math.ceil((vim.o.columns - 100) / 2),
      border = "rounded",
    },
  },
}
