return {
  {
    "kevinhwang91/nvim-ufo",
    event = "BufReadPre",
    dependencies = "kevinhwang91/promise-async",
    config = function()
      require("ufo").setup()

      -- Custom keymaps
      vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
    end,
  },
}
