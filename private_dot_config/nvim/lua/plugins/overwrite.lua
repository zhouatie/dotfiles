return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function(_, opts)
      opts.winopts = {
        height = 0.90, -- 窗口高度
        width = 0.80, -- 窗口宽度（设置为 1.00 表示全宽）
        row = 0.50, -- 窗口位置（0.50 表示在屏幕中间）
        col = 0.50, -- 窗口居中
        border = "single", -- 窗口边框样式
        preview = {
          layout = "vertical", -- 设置为上下布局
          height = "20", -- 预览窗口高度
        },
      }
    end,
  },

  -- {
  --   "nvim-neo-tree/neo-tree.nvim",
  --   cmd = "Neotree",
  --   opts = {
  --     window = {
  --       mappings = {
  --         ["o"] = "open",
  --       },
  --     },
  --   },
  -- },

  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
    },
  },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      -- 禁用 markdown 文件的 lint 检查
      linters_by_ft = {
        markdown = {}, -- 空数组表示禁用 markdown 的 lint
      },
    },
  },
}
