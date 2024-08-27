local neovimLines = {
  [[                                                                     ]],
  [[       ████ ██████           █████      ██                     ]],
  [[      ███████████             █████                             ]],
  [[      █████████ ███████████████████ ███   ███████████   ]],
  [[     █████████  ███    █████████████ █████ ██████████████   ]],
  [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
  [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
  [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
}

-- Define and set highlight groups for each logo line
vim.api.nvim_set_hl(0, "DashboardColor1", { fg = "#f38ba8" })
vim.api.nvim_set_hl(0, "DashboardColor2", { fg = "#eba0ac" })
vim.api.nvim_set_hl(0, "DashboardColor3", { fg = "#f5c2e7" })
vim.api.nvim_set_hl(0, "DashboardColor4", { fg = "#cba6f7" })
vim.api.nvim_set_hl(0, "DashboardColor5", { fg = "#89b4fa" })
vim.api.nvim_set_hl(0, "DashboardColor6", { fg = "#74c7ec" })
vim.api.nvim_set_hl(0, "DashboardColor7", { fg = "#89dceb" })
vim.api.nvim_set_hl(0, "DashboardColor8", { fg = "#94e2d5" })

local function lineColor(lines, popStart, popEnd)
  local out = {}
  for i, line in ipairs(lines) do
    local hi = "DashboardColor" .. i
    if i > popStart and i <= popEnd then
      hi = "DashboardColor" .. i - popStart
    elseif i > popStart then
      hi = "DashboardColor" .. i - popStart
    else
      hi = "DashboardColor" .. i
    end
    table.insert(out, { hi = hi, line = line })
  end
  return out
end

local headers = {
  lineColor(neovimLines, 1, 8),
}

local function header_chars()
  math.randomseed(os.time())
  return headers[math.random(#headers)]
end

-- Map over the headers, setting a different color for each line.
local function header_color()
  local lines = {}
  for _, lineConfig in pairs(header_chars()) do
    local hi = lineConfig.hi
    local line_chars = lineConfig.line
    local line = {
      type = "text",
      val = line_chars,
      opts = {
        hl = hi,
        shrink_margin = false,
        position = "center",
      },
    }
    table.insert(lines, line)
  end

  local output = {
    type = "group",
    val = lines,
    opts = { position = "center" },
  }

  return output
end

return {
  {
    "goolord/alpha-nvim",
    opts = function()
      local dashboard = require("alpha.themes.dashboard")

      -- stylua: ignore
      dashboard.section.buttons.val = {
          dashboard.button("f", " " .. " Find file",       "<cmd> Telescope find_files <cr>"),
          dashboard.button("n", "⊡ " .. " New file",        [[<cmd> ene <BAR> startinsert <cr>]]),
          dashboard.button("r", " " .. " Recent files",    "<cmd>  Telescope oldfiles <cr>"),
          dashboard.button("s", " " .. " Restore Session", [[<cmd> lua require("persistence").load() <cr>]]),
          dashboard.button("l", "󰒲 " .. " Lazy",            "<cmd> Lazy <cr>"),
          dashboard.button("m", "☷ " .. " Mason",           "<cmd> Mason <cr>"),
          dashboard.button("q", " " .. " Quit",            "<cmd> qa <cr>"),
      }
      for _, button in ipairs(dashboard.section.buttons.val) do
        button.opts.hl = "DashboardColor5"
        button.opts.hl_shortcut = "DashboardColor3"
      end
      dashboard.section.buttons.opts.hl = "DashboardColor3"
      dashboard.section.footer.opts.hl = "DashboardColor8"

      dashboard.config.layout = {
        { type = "padding", val = 8 },
        header_color(),
        { type = "padding", val = 4 },
        dashboard.section.buttons,
        { type = "padding", val = 2 },
        dashboard.section.footer,
      }

      return dashboard
    end,
  },
}
