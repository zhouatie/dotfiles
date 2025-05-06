return {
  -- 告别不良的vim操作习惯
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {},
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
    dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" },
    config = function()
      require("obsidian").get_client().opts.ui.enable = false
      local ns = vim.api.nvim_get_namespaces()["ObsidianUI"]
      if ns then
        vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
      end
      require("render-markdown").setup({})
    end,
  },

  -- 酷炫光标
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      stiffness_insert_mode = 0.6,
      trailing_stiffness_insert_mode = 0.6,
      distance_stop_animating = 0.5,
      cursor_color = "#47FF9C",
      legacy_computing_symbols_support = true,
    },
  },

  --- git-blame git 行 提交信息
  {
    "f-person/git-blame.nvim",
    event = "VeryLazy",
    opts = {
      enabled = true,
      message_template = "<author> • <summary> • <date>", -- <summary> • <date> • <author> • <<sha>>
      date_format = "%Y-%m-%d %H:%M:%S",
      virtual_text_column = 1,
    },
    init = function()
      vim.g.gitblame_message_when_not_committed = ""
      vim.g.gitblame_delay = 1000
    end,
  },

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

  -- neogit
  -- {
  --   "NeogitOrg/neogit",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim", -- required
  --     "sindrets/diffview.nvim", -- optional - Diff integration
  --
  --     -- Only one of these is needed.
  --     "nvim-telescope/telescope.nvim", -- optional
  --     "ibhagwan/fzf-lua", -- optional
  --     "echasnovski/mini.pick", -- optional
  --   },
  -- },

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
  --   dependencies = { { "echasnovski/mini.icons", opts = {} } },
  --   -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  --   -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  --   lazy = false,
  -- },
}
