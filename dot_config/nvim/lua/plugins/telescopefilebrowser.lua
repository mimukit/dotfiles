return {
  {
    "nvim-telescope/telescope-file-browser.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").load_extension("file_browser")

      vim.keymap.set("n", "<leader>sB", function()
        require("telescope").extensions.file_browser.file_browser({
          path = vim.fn.expand("%:p:h"),
          select_buffer = true,
        })
      end, { desc = "Telescope file browser" })
    end,
  },
}
