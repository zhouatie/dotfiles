return {
  {
    "zbirenbaum/copilot.lua",
    -- enabled = false,
    opts = function(_, opts)
      opts.filetypes = {
        ["*"] = true,
        ["markdown"] = false,
      }

      opts.suggestion = {
        enabled = true,
        auto_trigger = true,
        copilot_suggestion_hidden = true,
        hide_during_completion = true,
        debounce = 75, -- 增加防抖时间，减少过于频繁的触发
        trigger_on_accept = false, -- 修改为 false，避免连续自动完成可能带来的干扰
        keymap = {
          accept = "<M-l>",
          accept_word = "<M-w>", -- 启用接受单词的快捷键
          accept_line = "<M-;>", -- 启用接受整行的快捷键
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      }

      opts.panel = {
        enabled = true,
        auto_refresh = true, -- 修正了原配置中的拼写错误 'fal'
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<M-CR>",
        },
        layout = {
          position = "right", -- | top | left | right | horizontal | vertical
          ratio = 0.4,
        },
      }
    end,
    config = function(_, opts)
      require("copilot").setup(opts)
    end,
  },
}
