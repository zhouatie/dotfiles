return {
  "andrewferrier/debugprint.nvim",

  dependencies = {
    "nvim-mini/mini.nvim", -- Optional: Needed for line highlighting (full mini.nvim plugin)
    "nvim-mini/mini.hipatterns", -- Optional: Needed for line highlighting ('fine-grained' hipatterns plugin)
    "ibhagwan/fzf-lua", -- Optional: If you want to use the `:Debugprint search` command with fzf-lua
    "nvim-telescope/telescope.nvim", -- Optional: If you want to use the `:Debugprint search` command with telescope.nvim
    "folke/snacks.nvim", -- Optional: If you want to use the `:Debugprint search` command with snacks.nvim
  },
  -- 这一行很重要，确保 lazy.nvim 知道何时加载它
  event = "VeryLazy",
  -- 如果你想要更极致的懒加载，也可以用 keys 触发，但直接用 VeryLazy 最省心

  opts = {
    keymaps = {
      normal = {
        -- 1. 普通打印 (Plain)
        plain_below = "<leader>rp", -- 下方插入 print("...")
        plain_above = "<leader>rP", -- 上方插入

        -- 2. 变量打印 (Variable) & 文本对象 (Text Objects)
        -- 用法示例:
        --   <leader>rv + iw  => 打印当前单词
        --   <leader>rv + $   => 打印到行尾
        variable_below = "<leader>rv",
        variable_above = "<leader>rV",

        -- 3. 总是提示输入变量名 (Always Prompt)
        -- 对应你列表中的 variable_below_alwaysprompt
        variable_below_always_prompt = "<leader>ri",
        variable_above_always_prompt = "<leader>rI",

        -- 4. 清理与控制
        delete_debug_prints = "<leader>rc", -- 删除所有调试行
        toggle_comment_debug_prints = "<leader>rt", -- 切换注释状态

        -- textobj_below = "<leader>ro",
        -- textobj_above = "<leader>rO",
        -- textobj_surround = "<leader>rso",

        surround_plain = "<leader>rsp",
        surround_variable = "<leader>rsv",
      },
      visual = {
        -- 5. 视觉模式支持
        variable_below = "<leader>rv", -- 选中代码后按 <leader>rv 打印
        variable_above = "<leader>rV",
      },
    },

    display_counter = true, -- 是否显示递增数字 [1], [2]...
    display_snippet = true, -- 是否在打印信息里包含当前行的一小段代码摘要

    commands = {
      toggle_comment_debug_prints = "ToggleCommentDebugPrints",
      delete_prints = "DeleteDebugPrints",
    },
  },
}
