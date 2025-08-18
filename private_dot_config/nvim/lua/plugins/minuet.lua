return {
  {
    "milanglacier/minuet-ai.nvim",
    config = function()
      require("minuet").setup({
        -- provider = "openai_compatible",
        -- context_window = 16000,
        -- provider_options = {
        --   openai_compatible = {
        --     name = "Openrouter",
        --     end_point = "https://aihubmix.com/v1/chat/completions",
        --     model = "claude-3-7-sonnet-20250219",
        --     api_key = "AIHUBMIX_API_KEY",
        --     optional = { max_tokens = 128, top_p = 0.9 },
        --   },
        -- },

        provider = "openai_fim_compatible",
        n_completions = 1,
        context_window = 512,
        provider_options = {
          openai_fim_compatible = {
            api_key = "TERM",
            name = "Ollama",
            end_point = "http://localhost:11434/v1/completions",
            model = "qwen2.5-coder:7b",
            optional = {
              max_tokens = 56,
              top_p = 0.9,
            },
          },

          claude = {
            max_tokens = 512,
            model = "claude-3-5-haiku-20241022",
            -- system = "see [Prompt] section for the default value",
            -- few_shots = "see [Prompt] section for the default value",
            -- chat_input = "See [Prompt Section for default value]",
            stream = true,
            api_key = "ANTHROPIC_API_KEY",
            end_point = "https://gaccode.com/claudecode/v1/messages",
            optional = {
              -- pass any additional parameters you want to send to claude request,
              -- e.g.
              -- stop_sequences = nil,
            },
          },
        },
        virtualtext = {
          auto_trigger_ft = { "*" },
          keymap = {
            accept = "<Tab>",
            accept_line = "<D-a>",
            accept_n_lines = "<A-z>",
            prev = "<A-[>",
            next = "<A-]>",
            dismiss = "<A-e>",
          },
        },

        cmp = {
          enable_auto_complete = false,
        },
        blink = {
          enable_auto_complete = false,
        },
      })
    end,
  },

  { "nvim-lua/plenary.nvim" },
}
