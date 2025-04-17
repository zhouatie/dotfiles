return {
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
      provider = "copilot",

      copilot = {
        model = "claude-3.7-sonnet",
        endpoint = "https://api.githubcopilot.com",
        allow_insecure = false,
        timeout = 10 * 60 * 1000,
        temperature = 0,
        max_completion_tokens = 1000000,
        reasoning_effort = "high",
      },

      behaviour = {
        enable_cursor_planning_mode = true, -- Whether to enable Cursor Planning Mode. Default to false.
        enable_claude_text_editor_tool_mode = true, -- Whether to enable Claude Text Editor Tool Mode.
      },

      -- ollama = {
      --   model = "qwen2.5-coder:14b",
      -- },

      -- 可以用
      -- claude = {
      --   endpoint = "https://aihubmix.com/v1",
      --   model = "claude-3-7-sonnet-20250219",
      --   -- model = "Qwen/QwQ-32B",
      --   -- stream = true,
      --   -- model = "llama-3.3-70b-versatile",
      --   -- model = "claude-3-5-sonnet-20240620",
      --   -- model = "aihubmix-DeepSeek-R1",
      --   timeout = 30000, -- timeout in milliseconds
      --   temperature = 0, -- adjust if needed
      --   max_tokens = 8192,
      -- },
    },
    build = "make",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "echasnovski/mini.pick", -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua", -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
}
