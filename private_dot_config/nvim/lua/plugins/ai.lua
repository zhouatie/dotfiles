-- 设置 Avante 相关快捷键
vim.keymap.set("n", "<leader>an", function()
  vim.cmd("AvanteChatNew")
end, { desc = "AvanteChatNew" })

local function tokens(num)
  return num * 1024
end

return {
  {
    -- dir = "~/.config/nvim/clone/avante.nvim",
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false,
    -- commit = "f9aa75459d403d9e963ef2647c9791e0dfc9e5f9",
    -- version = "*", -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
      provider = "copilot",

      providers = {
        copilot = {
          model = "claude-3.7-sonnet",
          -- model = "gpt-4o", -- your desired model (or use gpt-4o, etc.)
          -- model = "o3-mini",
          endpoint = "https://api.githubcopilot.com",
          proxy = nil,
          allow_insecure = false,
          timeout = 10 * 60 * 1000,
          -- 8192
          max_completion_tokens = 20480,
          extra_request_body = {
            temperature = 0,
            max_tokens = 20480,
          },
          -- reasoning_effort = "high",
        },
        ["copilot:3.7"] = {
          __inherited_from = "copilot",
          model = "claude-3.7-sonnet",
          extra_request_body = {
            max_tokens = tokens(64),
          },
        },
        ["copilot:o3"] = {
          __inherited_from = "copilot",
          model = "o3-mini",
          extra_request_body = {
            max_tokens = tokens(64),
          },
        },
        deepseek = {
          __inherited_from = "openai",
          api_key_name = "DEEPSEEK_API_KEY",
          endpoint = "https://api.deepseek.com",
          model = "deepseek-coder",
        },
        qianwen = {
          __inherited_from = "openai",
          api_key_name = "DASHSCOPE_API_KEY",
          endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1",
          model = "qwen-coder-plus-latest",
        },

        ollama = {
          model = "qwen2.5-coder:14b",
        },

        -- 可以用
        aihubmix = {
          endpoint = "https://aihubmix.com/v1",
          model = "claude-3-7-sonnet-20250219",
          -- model = "Qwen/QwQ-32B",
          -- stream = true,
          -- model = "llama-3.3-70b-versatile",
          -- model = "claude-3-5-sonnet-20240620",
          -- model = "aihubmix-DeepSeek-R1",
          timeout = 30000, -- timeout in milliseconds
          temperature = 0, -- adjust if needed
          max_tokens = 8192,
        },
      },

      behaviour = {
        enable_cursor_planning_mode = true, -- Whether to enable Cursor Planning Mode. Default to false.
        enable_claude_text_editor_tool_mode = true, -- Whether to enable Claude Text Editor Tool Mode.
        enable_token_counting = false,
      },

      windows = {
        width = 40,
        input = {
          prefix = "",
          height = 22, -- Height of the input window in vertical layout
        },
      },

      -- rag_service = {
      --   enabled = true, -- Enables the RAG service
      --   host_mount = os.getenv("HOME"), -- Host mount path for the rag service
      --   provider = "ollama", -- The provider to use for RAG service (e.g. openai or ollama)
      --   llm_model = "qwen2.5-coder:14b", -- The LLM model to use for RAG service
      --   embed_model = "nomic-embed-text", -- The embedding model to use for RAG service
      --   endpoint = "http://localhost:11434", -- The API endpoint for RAG service
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

  {
    "saghen/blink.cmp",
    --optional = true,
    opts = {
      completion = {
        menu = {
          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "source_name" },
            },
            treesitter = { "lsp" },
          },
        },
      },

      sources = {
        default = { "avante_commands", "avante_mentions", "avante_files" },
        compat = {
          "avante_commands",
          "avante_mentions",
          "avante_files",
        },
        -- LSP score_offset is typically 60
        providers = {
          avante_commands = {
            name = "avante_commands",
            module = "blink.compat.source",
            score_offset = 90,
            opts = {},
          },
          avante_files = {
            name = "avante_files",
            module = "blink.compat.source",
            score_offset = 100,
            opts = {},
          },
          avante_mentions = {
            name = "avante_mentions",
            module = "blink.compat.source",
            score_offset = 1000,
            opts = {},
          },
        },
      },

      keymap = {
        preset = "enter",
        ["<C-y>"] = { "select_and_accept" },
        ["<C-o>"] = { "show" },
        ["<Tab>"] = {
          LazyVim.cmp.map({ "snippet_forward", "ai_accept" }),
          "fallback",
        },
      },
    },
    dependencies = { "saghen/blink.compat" },
  },
}
