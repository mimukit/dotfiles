local neovimLines = {
  [[                                                                       ]],
  [[                                                                       ]],
  [[                                                                       ]],
  [[                                                                       ]],
  [[                                                                     ]],
  [[       ████ ██████           █████      ██                     ]],
  [[      ███████████             █████                             ]],
  [[      █████████ ███████████████████ ███   ███████████   ]],
  [[     █████████  ███    █████████████ █████ ██████████████   ]],
  [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
  [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
  [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
  [[                                                                       ]],
  [[                                                                       ]],
  [[                                                                       ]],
}
local mivimLines = {
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[   ▄▄▄▄███▄▄▄▄    ▄█   ▄█    █▄   ▄█    ▄▄▄▄███▄▄▄▄   ]],
  [[ ▄██▀▀▀███▀▀▀██▄ ███  ███    ███ ███  ▄██▀▀▀███▀▀▀██▄ ]],
  [[ ███   ███   ███ ███▌ ███    ███ ███▌ ███   ███   ███ ]],
  [[ ███   ███   ███ ███▌ ███    ███ ███▌ ███   ███   ███ ]],
  [[ ███   ███   ███ ███▌ ███    ███ ███▌ ███   ███   ███ ]],
  [[ ███   ███   ███ ███  ███    ███ ███  ███   ███   ███ ]],
  [[ ███   ███   ███ ███  ███    ███ ███  ███   ███   ███ ]],
  [[  ▀█   ███   █▀  █▀    ▀██████▀  █▀    ▀█   ███   █▀  ]],
}

local mivimLines2 = {
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[ ███▄ ▄███▓ ██▓ ██▒   █▓ ██▓ ███▄ ▄███▓]],
  [[▓██▒▀█▀ ██▒▓██▒▓██░   █▒▓██▒▓██▒▀█▀ ██▒]],
  [[▓██    ▓██░▒██▒ ▓██  █▒░▒██▒▓██    ▓██░]],
  [[▒██    ▒██ ░██░  ▒██ █░░░██░▒██    ▒██ ]],
  [[▒██▒   ░██▒░██░   ▒▀█░  ░██░▒██▒   ░██▒]],
  [[░ ▒░   ░  ░░▓     ░ ▐░  ░▓  ░ ▒░   ░  ░]],
  [[░  ░      ░ ▒ ░   ░ ░░   ▒ ░░  ░      ░]],
  [[░      ░    ▒ ░     ░░   ▒ ░░      ░   ]],
  [[       ░    ░        ░   ░         ░   ]],
  [[                     ░                  ]],
}

local mivimLines3 = {
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[  ]],
  [[███╗   ███╗██╗██╗   ██╗██╗███╗   ███╗]],
  [[████╗ ████║██║██║   ██║██║████╗ ████║]],
  [[██╔████╔██║██║██║   ██║██║██╔████╔██║]],
  [[██║╚██╔╝██║██║╚██╗ ██╔╝██║██║╚██╔╝██║]],
  [[██║ ╚═╝ ██║██║ ╚████╔╝ ██║██║ ╚═╝ ██║]],
  [[╚═╝     ╚═╝╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝]],
}

local function lineColor(lines, popStart, popEnd)
  local out = {}
  for i, line in ipairs(lines) do
    local hi = 'StartLogo' .. i
    if i > popStart and i <= popEnd then
      hi = 'StartLogoPop' .. i - popStart
    elseif i > popStart then
      hi = 'StartLogo' .. i - popStart
    else
      hi = 'StartLogo' .. i
    end
    table.insert(out, { hi = hi, line = line })
  end
  return out
end

local headers = {
  lineColor(neovimLines, 6, 15),
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
      type = 'text',
      val = line_chars,
      opts = {
        hl = hi,
        shrink_margin = false,
        position = 'center',
      },
    }
    table.insert(lines, line)
  end

  local output = {
    type = 'group',
    val = lines,
    opts = { position = 'center' },
  }

  return output
end

local function configure()
  local theme = require 'alpha.themes.theta'
  local themeconfig = theme.config
  local dashboard = require 'alpha.themes.dashboard'
  local buttons = {
    type = 'group',
    val = {
      { type = 'text', val = 'Quick links', opts = { hl = 'SpecialComment', position = 'center' } },
      { type = 'padding', val = 1 },
      dashboard.button('e', '  New file', '<cmd>ene<CR>'),
      dashboard.button('<leader> s f', '  Find file'),
      dashboard.button('<leader> s w', '  Find text'),
      dashboard.button('u', '󱐥  Update plugins', '<cmd>Lazy sync<CR>'),
      dashboard.button('t', '  Install language tools', '<cmd>Mason<CR>'),
      dashboard.button('q', '󰩈  Quit', '<cmd>qa<CR>'),
    },
    position = 'center',
  }

  themeconfig.layout[2] = header_color()
  themeconfig.layout[6] = buttons

  return themeconfig
end

return {
  'goolord/alpha-nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    require('alpha').setup(configure())
  end,
}
