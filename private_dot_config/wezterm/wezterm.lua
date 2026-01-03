local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.show_tab_index_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false

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
	{
		key = "x",
		mods = "LEADER",
		action = wezterm.action.CloseCurrentPane({ confirm = true }),
	},

	-- 放大/隐藏其他窗格 (类似 tmux prefix+z)
	{ key = "z", mods = "LEADER", action = wezterm.action.TogglePaneZoomState },
	{
		key = "w",
		mods = "CMD",
		action = wezterm.action.CloseCurrentTab({ confirm = true }),
	},
	-- {
	-- 	key = "0",
	-- 	mods = "CMD",
	-- 	action = wezterm.action.ResizeWindow({ width = 120, height = 40 }),
	-- },
	-- {
	-- 	key = "Enter",
	-- 	mods = "ALT",
	-- 	action = wezterm.action.Nop,
	-- },
}

config.font = wezterm.font_with_fallback({
	-- "JetBrainsMono Nerd Font",
	-- "MesloLGS Nerd Font Mono",
	-- "Monaspace Neon",
	-- "Cascadia Code",
	"MesloLGS Nerd Font Mono",
})

config.font_size = 17
config.tab_max_width = 100
config.hide_tab_bar_if_only_one_tab = true

config.initial_rows = 40
config.initial_cols = 120

-- Set the default directory for new tabs
-- You can change the path to your desired directory
config.default_cwd = "/Users/zhoushitie/Desktop/work/"

config.enable_tab_bar = true

config.window_decorations = "RESIZE"
-- config.window_background_opacity = 0.8
-- config.macos_window_background_blur = 20

-- config.window_background_image = "/Users/zhoushitie/.config/wezterm-bg.jpeg"
config.window_background_image_hsb = {
	brightness = 0.06,
}

local tab_bar_bg = "rgba(0, 0, 0, 0)" -- 这里修改整栏的背景颜色

config.window_frame = {
	active_titlebar_bg = tab_bar_bg,
	inactive_titlebar_bg = tab_bar_bg,
}

config.colors = {
	tab_bar = {
		background = tab_bar_bg,
	},
}

config.max_fps = 120
-- config.confirm_close_tab = false
-- config.window_close_confirmation = false
config.default_cursor_style = "SteadyBlock"
config.cursor_blink_ease_out = "Constant"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_rate = 0
-- 抹茶主题
config.color_scheme = "Catppuccin Mocha"
config.use_fancy_tab_bar = false

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local background = "#1b1032"
	local foreground = "#808080"

	if tab.is_active then
		background = "#a277ff"
		foreground = "#214969"
	elseif hover then
		background = "#3b3052"
		foreground = "#909090"
	end

	local edge_background = tab_bar_bg
	local edge_foreground = background

	local title = tab.tab_title
	if not (title and #title > 0) then
		local cwd = tab.active_pane.current_working_dir
		if cwd then
			title = cwd.file_path
			title = string.match(title, "([^/]+)/?$") or title
		else
			title = tab.active_pane.title
		end
	end
	title = " " .. (tab.tab_index + 1) .. "." .. title .. " "

	local has_unseen_output = false
	if not tab.is_active then
		for _, pane in ipairs(tab.panes) do
			if pane.has_unseen_output then
				has_unseen_output = true
				break
			end
		end
	end

	local unseen = has_unseen_output and "" or ""

	return {
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = wezterm.nerdfonts.ple_lower_right_triangle },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = title .. unseen },
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = background } },
		{ Text = wezterm.nerdfonts.ple_upper_left_triangle },
	}
end)

return config
