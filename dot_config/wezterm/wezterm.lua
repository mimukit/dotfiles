--- wezterm.lua
--- $ figlet -f small Wezterm
--- __      __      _
--- \ \    / /__ __| |_ ___ _ _ _ __
---  \ \/\/ / -_)_ /  _/ -_) '_| '  \
---   \_/\_/\___/__|\__\___|_| |_|_|_|
---
--- My Wezterm config file
local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

local config = {}
-- Use config builder object if possible
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Settings

config.color_scheme = "Banana Blueberry"
-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = 'Outrun Dark (base16)'
-- config.color_scheme = 'Omni (Gogh)'
-- config.color_scheme = 'Nightfly (Gogh)'
-- config.color_scheme = "Ef-Deuteranopia-Dark"

config.font = wezterm.font_with_fallback({
	{
		family = "MesloLGS Nerd Font Mono",
		weight = "Medium",
	},
	{
		family = "FiraMono Nerd Font Mono",
		scale = 1.2,
		weight = "Medium",
	},
	{
		family = "Arial",
		scale = 1.2,
	},
})

config.font_size = 13.0
config.line_height = 1.2

config.window_background_opacity = 0.97
config.window_decorations = "RESIZE"
config.window_close_confirmation = "NeverPrompt"
config.scrollback_lines = 100000
config.default_workspace = "main"
config.window_frame = {
	border_left_width = "0cell",
	border_right_width = "0cell",
	border_top_height = "0.1cell",
	border_bottom_height = "0cell",
	border_left_color = "#dc8a78",
	border_right_color = "#dc8a78",
	border_top_color = "#dc8a78",
	border_bottom_color = "#dc8a78",
}

-- Dim inactive panes
config.inactive_pane_hsb = {
	saturation = 0.24,
	brightness = 0.5,
}

-- Tab bar
-- I don't like the look of "fancy" tab bar
config.enable_tab_bar = false
config.use_fancy_tab_bar = true
config.status_update_interval = 1000
config.tab_bar_at_bottom = false
wezterm.on("update-status", function(window, pane)
	-- Workspace name
	local stat = window:active_workspace()
	local stat_color = "#f7768e"
	-- It's a little silly to have workspace name all the time
	-- Utilize this to display LDR or current key table name
	if window:active_key_table() then
		stat = window:active_key_table()
		stat_color = "#7dcfff"
	end
	if window:leader_is_active() then
		stat = "LDR"
		stat_color = "#bb9af7"
	end

	local basename = function(s)
		-- Nothing a little regex can't fix
		return string.gsub(s, "(.*[/\\])(.*)", "%2")
	end

	-- Current working directory
	local cwd = pane:get_current_working_dir()
	if cwd then
		if type(cwd) == "userdata" then
			-- Wezterm introduced the URL object in 20240127-113634-bbcac864
			cwd = basename(cwd.file_path)
		else
			-- 20230712-072601-f4abf8fd or earlier version
			cwd = basename(cwd)
		end
	else
		cwd = ""
	end

	-- Current command
	local cmd = pane:get_foreground_process_name()
	-- CWD and CMD could be nil (e.g. viewing log using Ctrl-Alt-l)
	cmd = cmd and basename(cmd) or ""

	-- Time
	local time = wezterm.strftime("%H:%M")

	-- Left status (left of the tab line)
	window:set_left_status(wezterm.format({
		{
			Foreground = {
				Color = stat_color,
			},
		},
		{
			Text = "  ",
		},
		{
			Text = wezterm.nerdfonts.oct_table .. "  " .. stat,
		},
		{
			Text = " |",
		},
	}))

	-- Right status
	window:set_right_status(wezterm.format({ -- Wezterm has a built-in nerd fonts
		-- https://wezfurlong.org/wezterm/config/lua/wezterm/nerdfonts.html
		{
			Text = wezterm.nerdfonts.md_folder .. "  " .. cwd,
		},
		{
			Text = " | ",
		},
		{
			Foreground = {
				Color = "#e0af68",
			},
		},
		{
			Text = wezterm.nerdfonts.fa_code .. "  " .. cmd,
		},
		"ResetAttributes",
		{
			Text = " | ",
		},
		{
			Text = wezterm.nerdfonts.md_clock .. "  " .. time,
		},
		{
			Text = "  ",
		},
	}))
end)

config.window_padding = {
	left = "1cell",
	right = "1cell",
	top = "0.5cell",
	bottom = "0cell",
}

-- Fullscreen at startup
wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

return config
