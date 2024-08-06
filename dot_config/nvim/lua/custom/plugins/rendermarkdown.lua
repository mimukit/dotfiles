return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    event = 'VeryLazy',
    ft = 'markdown',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
    opts = {},
  },
}
