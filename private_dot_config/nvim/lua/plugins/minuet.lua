local function tokens(num)
  return num * 1024
end

local codemaker = require("codemaker")
local codemaker_provider = require("plugins.minuet.codemaker")

-- gpt-4o-mini > gemini-2.0-flash
return {
  {
    "milanglacier/minuet-ai.nvim",
    ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    config = function()
      -- codemaker.proxy = codemaker.proxy or "http://127.0.0.1:8899"

      if not codemaker.ensure_curl() then
        -- vim.notify("CodeMaker token refresh skipped: plenary.curl not available", vim.log.levels.WARN)
      else
        codemaker.refresh()
      end

      require("minuet").setup({
        provider = "openai_fim_compatible",
        -- provider = "openai_compatible",

        -- proxy = "http://127.0.0.1:8899",
        -- notify = "debug",
        notify = false,
        n_completions = 1,
        -- context_window = 512,
        context_window = tokens(64),
        after_cursor_filter_length = 1,
        provider_options = {
          openai_fim_compatible = codemaker_provider,

          -- openai_fim_compatible = {
          --   api_key = function()
          --     return os.getenv("AIHUBMIX_COMPLETE_API_KEY")
          --   end,
          --   stream = false,
          --   end_point = "https://aihubmix.com/v1/completions",
          --   -- model = "glm-4.7",
          --   -- model = "QwQ-32B",
          --   model = "coding-glm-4.7-free",
          --   name = "AIHubMix",
          --   optional = {
          --     max_tokens = 128,
          --     top_p = 0.9,
          --   },
          -- },

          -- openai_fim_compatible = {
          --   api_key = "TERM",
          --   name = "Ollama",
          --   end_point = "http://localhost:11434/v1/completions",
          --   model = "qwen2.5-coder:7b",
          --   optional = {
          --     max_tokens = 256,
          --     top_p = 0.9,
          --   },
          -- },
        },
        virtualtext = {
          -- auto_trigger_ft = { "*" },
          auto_trigger_ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
          keymap = {
            accept = "<Tab>",
            next = "<C-;>",
            accept_line = "<C-l>",
            -- accept_n_lines = "<A-z>",
            -- prev = "<A-[>",
            -- next = "<A-]>",
            -- dismiss = "<A-e>",
          },
          show_on_completion_menu = false,
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
