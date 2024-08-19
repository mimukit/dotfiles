local colors = {
  black = "#080808",
  blue = "#89b4fa",
  green = "#a6e3a1",
  mauve = "#cba6f7",
  peach = "#fab387",
  surface = "#313244",
  red = "#f38ba8",
  white = "#cdd6f4",
}

local catppuccin_custom = {
  normal = {
    a = { fg = colors.black, bg = colors.peach },
    b = { fg = colors.white, bg = colors.surface },
    c = { fg = colors.white },

    -- x = { fg = colors.white },
    -- y = { fg = colors.white, bg = colors.surface },
    -- z = { fg = colors.black, bg = colors.peach },
  },

  insert = { a = { fg = colors.black, bg = colors.green } },
  visual = { a = { fg = colors.black, bg = colors.blue } },
  replace = { a = { fg = colors.black, bg = colors.red } },
  command = { a = { fg = colors.black, bg = colors.mauve } },

  inactive = {
    a = { fg = colors.white, bg = colors.surface },
    b = { fg = colors.white, bg = colors.surface },
    c = { fg = colors.white },
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
