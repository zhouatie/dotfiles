return {
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    enabled = true,
    init = false,
    opts = function()
      local dashboard = require("alpha.themes.dashboard")

      -- 自定义的 Logo
      local logo = [[
   _   _      _ _        __        __         _     _ _
  | | | | ___| | | ___   \ \      / /__  _ __| | __| | |
  | |_| |/ _ \ | |/ _ \   \ \ /\ / / _ \| '__| |/ _` | |
  |  _  |  __/ | | (_) |   \ V  V / (_) | |  | | (_| |_|
  |_| |_|\___|_|_|\___/     \_/\_/ \___/|_|  |_|\__,_(_)

   ___ _                   _   _
  |_ _( )_ __ ___     __ _| |_(_) ___
   | ||/| '_ ` _ \   / _` | __| |/ _ \
   | |  | | | | | | | (_| | |_| |  __/
  |___| |_| |_| |_|  \__,_|\__|_|\___|


                ▀████▀▄▄              ▄█
                  █▀    ▀▀▄▄▄▄▄    ▄▄▀▀█
          ▄        █          ▀▀▀▀▄  ▄▀
         ▄▀ ▀▄      ▀▄              ▀▄▀
        ▄▀    █     █▀   ▄█▀▄      ▄█
        ▀▄     ▀▄  █     ▀██▀     ██▄█
         ▀▄    ▄▀ █   ▄██▄   ▄  ▄  ▀▀ █
          █  ▄▀  █    ▀██▀    ▀▀ ▀▀  ▄▀
         █   █  █      ▄▄           ▄▀
      ]]

      dashboard.section.header.val = vim.split(logo, "\n")

      -- 设置文本居中
      dashboard.section.header.opts = {
        position = "center",
        hl = "Type",
      }

      -- 清空按钮和导航栏
      dashboard.section.buttons.val = {}

      return dashboard
    end,
  },
}
