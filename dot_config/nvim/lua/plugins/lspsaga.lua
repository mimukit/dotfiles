return {
  {
    "nvimdev/lspsaga.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-treesitter/nvim-treesitter", -- optional
    },
    config = function()
      require("lspsaga").setup({
        lightbulb = {
          enable = false,
        },
        outline = {
          win_width = 50,
        },
      })
    end,

    -- stylua: ignore
    keys = {
      { "<leader>cga", "<cmd>Lspsaga code_action<cr>", desc = "Lspsaga code action" },
      { "<leader>cgd", "<cmd>Lspsaga goto_definition<cr>", desc = "Lapsaga goto definition" },
      { "<leader>cgf", "<cmd>Lspsaga finder<cr>", desc = "Lspsaga finder" },
      { "<leader>cgo", "<cmd>Lspsaga outline<cr>", desc = "Lspsaga outline" },
      { "<leader>cgr", "<cmd>Lspsaga rename<cr>", desc = "Lspsaga rename" },
      { "<leader>cgw", "<cmd>Lspsaga show_workspace_diagnostics<cr>", desc = "Lapsaga show workspace diagnostics",},
      { "<leader>cgK", "<cmd>Lspsaga hover_doc<cr>", desc = "Lspsaga hover doc" },

      { "<leader>co", "<cmd>Lspsaga outline<cr>", desc = "Lspsaga outline" },
    },
  },
}
