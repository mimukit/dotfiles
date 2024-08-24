-- set undotree window layout
vim.g.undotree_WindowLayout = 4

return {
  {
    "mbbill/undotree",
    event = "VeryLazy",
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "Toggle undo tree" },
    },
  },
}
