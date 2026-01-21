return {
  {
    "LazyVim/LazyVim",
    opts = {
      -- colorscheme = "rose-pine-moon",
      colorscheme = "catppuccin",
    },
  },

  {
    "catppuccin/nvim",
    lazy = false,
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha", -- latte, frappe, macchiato, mocha
      transparent_background = true,
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- {
  --   "folke/tokyonight.nvim",
  --   lazy = false,
  --   priority = 1000,
  --   opts = {
  --     transparent = true,
  --     styles = {
  --       sidebars = "transparent",
  --       floats = "transparent",
  --     },
  --   },
  -- },

  -- {
  --   "rose-pine/neovim",
  --   name = "rose-pine-moon",
  --   config = function()
  --     require("rose-pine").setup({
  --       styles = {
  --         transparency = true, -- 启用透明背景
  --       },
  --       highlight_groups = {
  --         CursorLine = { bg = "base", blend = 10 },
  --         Visual = { bg = "rose", blend = 20 }, -- 可视模式选中背景
  --         VisualNOS = { bg = "rose", blend = 20 }, -- 非拥有选择的可视模式
  --       },
  --     })
  --   end,
  -- },
  --
}
