-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- my coolnight colorscheme
config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "#47FF9C",
	cursor_border = "#47FF9C",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE4F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#24EAF7" },
	brights = { "#666666", "#E52E2E", "#44FFB1", "#FFE073", "#A277FF", "#a277ff", "#24EAF7", "#24EAF7" },
}

config.leader = { key = "a", mods = "SUPER", timeout_millithirds = 1000 }
config.keys = {
	{
		key = "-",
		mods = "LEADER",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "_",
		mods = "LEADER",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "j",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Down"),
	},
	{
		key = "k",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Up"),
	},
	{
		key = "h",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Left"),
	},
	{
		key = "l",
		mods = "LEADER",
		action = wezterm.action.ActivatePaneDirection("Right"),
	},
	-- {
	-- 	key = "h",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = wezterm.action.AdjustPaneSize({ "Left", 5 }),
	-- },
	-- {
	-- 	key = "l",
	-- 	mods = "LEADER|SHIFT",
	-- 	action = wezterm.action.AdjustPaneSize({ "Right", 5 }),
	-- },
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentTab({ confirm = false }),
	},
}
-- ctrl + shift + alt + 左右箭头移动面板宽度

config.font = wezterm.font("MesloLGS Nerd Font Mono", { weight = "Bold" })
config.font_size = 16

config.initial_rows = 45
config.initial_cols = 140

config.enable_tab_bar = true

config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 15

config.max_fps = 120
-- config.confirm_close_tab = false
-- config.window_close_confirmation = false
config.default_cursor_style = "SteadyBlock"
config.cursor_blink_ease_out = "Constant"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_rate = 0
-- and finally, return the configuration to wezterm
return config
