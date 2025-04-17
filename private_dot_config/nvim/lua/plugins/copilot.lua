return {
  {
    "zbirenbaum/copilot.lua",
    opts = function(_, opts)
      opts.filetypes = {
        ["*"] = true,
      }

      opts.suggestion = {
        enabled = true,
        auto_trigger = true,
        hide_during_completion = true,
        debounce = 25,
        trigger_on_accept = true,
        keymap = {
          accept = "<M-l>",
          accept_word = false,
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      }

      -- opts.panel = {
      --   enabled = true,
      --   auto_refresh = fal,
      --   keymap = {
      --     jump_prev = "[[",
      --     jump_next = "]]",
      --     accept = "<CR>",
      --     refresh = "gr",
      --     open = "<M-CR>",
      --   },
      --   layout = {
      --     position = "bottom", -- | top | left | right | horizontal | vertical
      --     ratio = 0.4,
      --   },
      -- }
    end,
  },
}
