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
-- This is done by setting the Highligh to StartLogoN, where N is the row index.
-- Define StartLogo1..StartLogoN to get a nice gradient.
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

local function configure()
  local theme = require("alpha.themes.theta")
  local themeconfig = theme.config
  local dashboard = require("alpha.themes.dashboard")

  local buttons = {
    type = "group",
    val = {
      { type = "text", val = "Quick links", opts = { hl = "DashboardColor3", position = "center" } },
      { type = "padding", val = 2 },
      dashboard.button("f", " " .. " Find file", "<cmd> Telescope find_files <cr>"),
      { type = "padding", val = 1 },
      dashboard.button("n", "⊡ " .. " New file", [[<cmd> ene <BAR> startinsert <cr>]]),
      { type = "padding", val = 1 },
      dashboard.button("r", " " .. " Recent files", "<cmd>  Telescope oldfiles <cr>"),
      { type = "padding", val = 1 },
      dashboard.button("s", " " .. " Restore Session", [[<cmd> lua require("persistence").load() <cr>]]),
      { type = "padding", val = 1 },
      dashboard.button("l", "󰒲 " .. " Lazy", "<cmd> Lazy <cr>"),
      { type = "padding", val = 1 },
      dashboard.button("m", "☷ " .. " Mason", "<cmd> Mason <cr>"),
      { type = "padding", val = 1 },
      dashboard.button("q", " " .. " Quit", "<cmd> qa <cr>"),
    },
    position = "center",
  }

  themeconfig.layout = {
    { type = "padding", val = 8 },
    header_color(),
    { type = "padding", val = 2 },
    buttons,
    { type = "padding", val = 2 },
  }

  return themeconfig
end

return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  enabled = true,
  init = false,
  config = function()
    -- close Lazy and re-open when the dashboard is ready
    if vim.o.filetype == "lazy" then
      vim.cmd.close()
      vim.api.nvim_create_autocmd("User", {
        once = true,
        pattern = "AlphaReady",
        callback = function()
          require("lazy").show()
        end,
      })
    end

    require("alpha").setup(configure())

    vim.api.nvim_create_autocmd("User", {
      once = true,
      pattern = "LazyVimStarted",
      callback = function()
        local theme = require("alpha.themes.theta")
        local themeconfig = theme.config
        local stats = require("lazy").stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)

        themeconfig.layout[6] = {
          type = "text",
          val = "⚡ Neovim loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms .. "ms",
          opts = {
            hl = "DashboardColor8",
            position = "center",
          },
        }
        pcall(vim.cmd.AlphaRedraw)
      end,
    })
  end,
}
