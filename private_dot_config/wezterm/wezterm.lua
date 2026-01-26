local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- ============================================================================
-- 基础配置
-- ============================================================================

-- 字体配置
config.font = wezterm.font_with_fallback({
	{ family = "JetBrainsMono Nerd Font" },
	{ family = "Noto Sans CJK SC" },
})
config.font_size = 17
config.line_height = 1.1

-- 窗口尺寸
config.initial_rows = 40
config.initial_cols = 120
config.adjust_window_size_when_changing_font_size = false

-- 默认工作目录
config.default_cwd = "/Users/zhoushitie/Desktop/work/"
config.window_close_confirmation = "NeverPrompt"

-- ============================================================================
-- 键位绑定
-- ============================================================================

config.leader = { key = "a", mods = "SUPER", timeout_millithirds = 1000 }
config.keys = {
	-- 分屏操作
	{ key = "-", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "_", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- 窗格导航 (vim 风格)
	{ key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },

	-- 窗格管理
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "z", mods = "LEADER", action = wezterm.action.TogglePaneZoomState },

	-- 标签管理
	{ key = "w", mods = "CMD", action = wezterm.action.CloseCurrentTab({ confirm = true }) },
}

-- ============================================================================
-- 外观主题
-- ============================================================================

-- 颜色主题
config.color_scheme = "Catppuccin Mocha"

-- 光标配置
config.default_cursor_style = "SteadyBlock"
config.cursor_blink_ease_out = "Constant"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_rate = 0

-- 性能
config.max_fps = 120

-- 移除窗口内边距（去掉底部空行）
config.window_padding = {
	-- left = 0,
	-- right = 0,
	-- top = 0,
	bottom = 0,
}

-- 背景配置
config.window_background_image_hsb = {
	brightness = 0.06,
}
-- 非活动窗格外观
config.inactive_pane_hsb = {
	saturation = 1,
	brightness = 0.6,
}

-- ============================================================================
-- 窗口装饰
-- ============================================================================

local border_color = "#F0F8FF"
local tab_bar_bg = "rgba(0, 0, 0, 0)"

config.window_decorations = "RESIZE"
config.window_frame = {
	active_titlebar_bg = tab_bar_bg,
	inactive_titlebar_bg = tab_bar_bg,
	border_left_width = "0.25cell",
	border_right_width = "0.25cell",
	border_bottom_height = "0.125cell",
	border_top_height = "0.125cell",
	border_left_color = border_color,
	border_right_color = border_color,
	border_bottom_color = border_color,
	border_top_color = border_color,
}

config.colors = {
	split = border_color,
	tab_bar = {
		background = tab_bar_bg,
	},
}

-- ============================================================================
-- 标签栏配置
-- ============================================================================

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.show_tab_index_in_tab_bar = false
config.show_new_tab_button_in_tab_bar = false
config.tab_max_width = 100

-- 自定义标签标题格式
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
