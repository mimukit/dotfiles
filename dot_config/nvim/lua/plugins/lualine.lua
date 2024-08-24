local colors = require("catppuccin.palettes").get_palette("mocha")

local catppuccin_custom = {
  normal = {
    a = { fg = colors.crust, bg = colors.peach },
    b = { fg = colors.text, bg = colors.surface0 },
    c = { fg = colors.text },

    -- x = { fg = colors.text },
    -- y = { fg = colors.text, bg = colors.surface0 },
    -- z = { fg = colors.crust, bg = colors.peach },
  },

  insert = { a = { fg = colors.crust, bg = colors.green } },
  visual = { a = { fg = colors.crust, bg = colors.blue } },
  replace = { a = { fg = colors.crust, bg = colors.red } },
  command = { a = { fg = colors.crust, bg = colors.mauve } },

  inactive = {
    a = { fg = colors.text, bg = colors.surface0 },
    b = { fg = colors.text, bg = colors.surface0 },
    c = { fg = colors.text },
  },
}

return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        theme = catppuccin_custom,
        component_separators = "",
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = { { "mode", separator = { left = "", right = "" }, padding = { left = 1, right = 1 } } },
        lualine_y = {
          "filetype",
        },
        lualine_z = {
          { "location", separator = " ", padding = { left = 0, right = 0 } },
          { "progress", padding = { left = 0, right = 1 }, separator = { right = "" } },
        },
      },
    },
  },
}
