-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {
	base46 = {
		theme = "catppuccin",
		transparency = true,
	},

	ui = {
		statusline = {
			theme = "minimal",
			separator_style = "round",
		},

		nvdash = {
			load_on_startup = true,
		},
	},

	term = {
		winopts = { number = false, relativenumber = false },
		sizes = { sp = 0.3, vsp = 0.4, ["bo sp"] = 0.3, ["bo vsp"] = 0.4 },
		float = {
			relative = "editor",
			row = 0.1,
			col = 0.2,
			width = 0.7,
			height = 0.6,
			border = "single",
		},
	},
}

return M
