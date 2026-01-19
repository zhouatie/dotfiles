return {
  {
    "nvim-zh/colorful-winsep.nvim",
    config = true,
    event = { "WinLeave" },
  },

  -- { "folke/neodev.nvim", enabled = false }, -- make sure to uninstall or disable neodev.nvim

  -- {
  --   "NeogitOrg/neogit",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim", -- required
  --     "sindrets/diffview.nvim", -- optional - Diff integration
  --
  --     -- Only one of these is needed.
  --     "nvim-telescope/telescope.nvim", -- optional
  --     "ibhagwan/fzf-lua", -- optional
  --     "nvim-mini/mini.pick", -- optional
  --     "folke/snacks.nvim", -- optional
  --   },
  --   keys = {
  --     {
  --       "<leader>gg",
  --       function()
  --         require("neogit").open()
  --       end,
  --       desc = "Open Neogit",
  --     },
  --   },
  --   config = function()
  --     require("neogit").setup()
  --   end,
  -- },

  -- 单行导航
  -- {
  --   "tris203/precognition.nvim",
  --   --event = "VeryLazy",
  --   opts = {
  --     -- startVisible = true,
  --     -- showBlankVirtLine = true,
  --     -- highlightColor = { link = "Comment" },
  --     -- hints = {
  --     --      Caret = { text = "^", prio = 2 },
  --     --      Dollar = { text = "$", prio = 1 },
  --     --      MatchingPair = { text = "%", prio = 5 },
  --     --      Zero = { text = "0", prio = 1 },
  --     --      w = { text = "w", prio = 10 },
  --     --      b = { text = "b", prio = 9 },
  --     --      e = { text = "e", prio = 8 },
  --     --      W = { text = "W", prio = 7 },
  --     --      B = { text = "B", prio = 6 },
  --     --      E = { text = "E", prio = 5 },
  --     -- },
  --     -- gutterHints = {
  --     --     G = { text = "G", prio = 10 },
  --     --     gg = { text = "gg", prio = 9 },
  --     --     PrevParagraph = { text = "{", prio = 8 },
  --     --     NextParagraph = { text = "}", prio = 8 },
  --     -- },
  --     -- disabled_fts = {
  --     --     "startify",
  --     -- },
  --   },
  -- },
  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    keys = {
      {
        "<C-h>",
        function()
          require("tmux").move_left()
        end,
        desc = "Move to left pane",
      },
      {
        "<C-j>",
        function()
          require("tmux").move_bottom()
        end,
        desc = "Move to bottom pane",
      },
      {
        "<C-k>",
        function()
          require("tmux").move_top()
        end,
        desc = "Move to top pane",
      },
      {
        "<C-l>",
        function()
          require("tmux").move_right()
        end,
        desc = "Move to right pane",
      },
    },
    config = function()
      require("tmux").setup({
        copy_sync = {
          enable = true,
        },
        navigation = {
          enable_default_keybindings = false, -- 禁用默认键绑定，使用我们自定义的
        },
        resize = {
          enable_default_keybindings = false,
        },
      })
    end,
  },

  {
    "sontungexpt/url-open",
    event = "VeryLazy",
    cmd = "URLOpenUnderCursor",
    config = function()
      local status_ok, url_open = pcall(require, "url-open")
      if not status_ok then
        return
      end
      url_open.setup({})
    end,
  },
  -- gb 打开当前所有标签页
  {
    "leath-dub/snipe.nvim",
    event = "VeryLazy",
    keys = {
      {
        "gb",
        function()
          require("snipe").open_buffer_menu()
        end,
        desc = "Open Snipe buffer menu",
      },
    },
    opts = {},
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    cmd = { "RenderMarkdown" },
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
    config = function()
      local ns = vim.api.nvim_get_namespaces()["ObsidianUI"]
      if ns then
        vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      end
      require("render-markdown").setup({})
    end,
  },

  -- 酷炫光标
  -- {
  --   "sphamba/smear-cursor.nvim",
  --   opts = {
  --     stiffness = 0.8,
  --     trailing_stiffness = 0.5,
  --     stiffness_insert_mode = 0.6,
  --     trailing_stiffness_insert_mode = 0.6,
  --     distance_stop_animating = 0.5,
  --     cursor_color = "#47FF9C",
  --     legacy_computing_symbols_support = true,
  --   },
  -- },

  -- yazi
  {
    "mikavilpas/yazi.nvim",
    event = "VeryLazy",
    dependencies = {
      -- check the installation instructions at
      -- https://github.com/folke/snacks.nvim
      "folke/snacks.nvim",
    },
    keys = {
      -- 👇 in this section, choose your own keymappings!
      {
        "<leader>y",
        mode = { "n", "v" },
        "<cmd>Yazi<cr>",
        desc = "Open yazi at the current file",
      },
      {
        -- Open in the current working directory
        "<leader>cw",
        "<cmd>Yazi cwd<cr>",
        desc = "Open the file manager in nvim's working directory",
      },
      {
        "<c-up>",
        "<cmd>Yazi toggle<cr>",
        desc = "Resume the last yazi session",
      },
    },
    ---@type YaziConfig | {}
    opts = {
      -- if you want to open yazi instead of netrw, see below for more info
      open_for_directories = false,
      keymaps = {
        show_help = "<f1>",
      },
    },
    -- 👇 if you use `open_for_directories=true`, this is recommended
    init = function()
      -- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
      -- vim.g.loaded_netrw = 1
      vim.g.loaded_netrwPlugin = 1
    end,
  },

  -- 右上角文件标签
  {
    "b0o/incline.nvim",
    config = function()
      require("incline").setup()
    end,
    -- Optional: Lazy load Incline
    event = "VeryLazy",
  },

  -- {
  --   "ravitemer/mcphub.nvim",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
  --   },
  --   -- comment the following line to ensure hub will be ready at the earliest
  --   cmd = "MCPHub", -- lazy load by default
  --   build = "cnpm install -g mcp-hub@latest", -- Installs required mcp-hub npm module
  --   -- uncomment this if you don't want mcp-hub to be available globally or can't use -g
  --   -- build = "bundled_build.lua",  -- Use this and set use_bundled_binary = true in opts  (see Advanced configuration)
  --   config = function()
  --     require("mcphub").setup()
  --   end,
  -- },

  -- vim 中操作文件
  -- {
  --   "stevearc/oil.nvim",
  --   ---@module 'oil'
  --   ---@type oil.SetupOpts
  --   opts = {},
  --   -- Optional dependencies
  --   dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  --   -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  --   -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  --   lazy = false,
  -- },
}
