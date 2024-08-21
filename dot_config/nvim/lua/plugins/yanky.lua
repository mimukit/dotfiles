return {
  {
    "gbprod/yanky.nvim",
    opts = {
      highlight = {
        on_put = false,
        on_yank = false,
        timer = 500,
      },
    },
    keys = {
      -- Replace yank history trigger
      { "<leader>p", false },
      {
        "<leader>sp",
        function()
          if LazyVim.pick.picker.name == "telescope" then
            require("telescope").extensions.yank_history.yank_history({})
          else
            vim.cmd([[YankyRingHistory]])
          end
        end,
        mode = { "n", "x" },
        desc = "Open Yank History",
      },
    },
  },
}
