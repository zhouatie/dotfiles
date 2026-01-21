return {
  {
    "nvim-orgmode/orgmode",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      "nvim-orgmode/telescope-orgmode.nvim",
      "nvim-orgmode/org-bullets.nvim",
      "Saghen/blink.cmp",
      "danilshvalov/org-modern.nvim",
    },
    event = "VeryLazy",
    config = function()
      local Menu = require("org-modern.menu")

      require("orgmode").setup({
        ui = {
          menu = {
            handler = function(data)
              Menu:new({
                window = {
                  margin = { 1, 0, 1, 0 },
                  padding = { 0, 1, 0, 1 },
                  title_pos = "center",
                  border = "single",
                  zindex = 1000,
                },
                icons = {
                  separator = "➜",
                },
              }):open(data)
            end,
          },
        },
        org_agenda_files = { "~/org/inbox.org", "~/org/gtd/**/*.org", "~/org/notes/**/*.org" },
        org_default_notes_file = "~/org/inbox.org",
        -- win_split_mode = "vertical",
        -- org_agenda_skip_deadline_if_done = true,
        -- org_agenda_skip_scheduled_if_done = true,
        org_agenda_sorting_strategy = {
          agenda = { "todo-state-down", "time-up", "priority-down", "category-keep" },
          todo = { "todo-state-down", "priority-down", "category-keep" },
          tags = { "todo-state-down", "priority-down", "category-keep" },
        },
        org_todo_keywords = {
          -- 1. 开发阶段
          "TODO(t)", -- 待办：池子里的任务
          "NEXT(n)", -- 计划：今天或马上要做的
          "DOING(i)", -- 进行中：正在写代码 (In Progress)

          -- 2. 阻塞与等待 (前端常见痛点)
          "BLOCKED(b)", -- 阻塞：例如后端接口 500，或者 UI 图没给全
          "WAITING(w)", -- 等待：例如等产品确认需求变更

          -- 3. 验收与发布阶段
          "VERIFY(v)", -- 验证：部署到测试环境，等 QA 或自己在测 (待验证)
          "REVIEW(r)", -- 审查：已提 PR，等同事 Review
          "RELEASE(p)", -- 发布：测试通过，等待上线窗口 (待发布/Pre-release)

          "|", -- 分割线：左边是未完成，右边是已完成

          -- 4. 结束状态
          "DONE(d)", -- 完成
          "DELEGATED(g)", -- 委派：甩锅给后端或者运维了
          "CANCELLED(c)", -- 取消：需求砍了
        },

        org_todo_keyword_faces = {
          -- 1. 开发阶段：暖色调，但不刺眼
          -- 柔和的橘粉色，代替大红
          TODO = ":foreground #D08770 :weight bold",
          -- 奶酪黄/沙色，代替荧光黄
          NEXT = ":foreground #EBCB8B :weight bold",
          -- 雾霾蓝/灰蓝色，冷静专注，代替亮蓝
          DOING = ":foreground #88C0D0 :weight bold",

          -- 2. 阻塞与等待：偏紫/粉色系，起到提示作用但不过分抢眼
          -- 干燥玫瑰色，用于阻塞
          BLOCKED = ":foreground #BF616A :slant italic",
          -- 薰衣草紫，用于等待
          WAITING = ":foreground #B48EAD :slant italic",

          -- 3. 验收与发布：清新的冷色调
          -- 湖水绿/青色，代表接近完成
          VERIFY = ":foreground #81A1C1",
          REVIEW = ":foreground #8FBCBB",
          -- 抹茶绿，代表蓄势待发
          RELEASE = ":foreground #A3BE8C :weight bold",

          "|", -- 分割线：左边是未完成，右边是已完成

          -- 4. 结束状态：低调的颜色
          -- 灰绿色，柔和的完成感
          DONE = ":foreground #A3BE8C :weight bold",
          -- 浅灰色，融入背景，不再干扰视线
          DELEGATED = ":foreground #6E7582 :slant italic",
          CANCELLED = ":foreground #6E7582 :slant italic",
        },

        org_capture_templates = {
          -- 1. 任务流 (Tasks)
          t = {
            description = "待办任务",
            template = "* TODO %?\n  SCHEDULED: %t\n",
            target = "~/org/inbox.org",
          },
          d = {
            description = "☀️ 晨间规划 (Daily Start)",
            -- 目标文件
            target = "~/org/gtd/%<%Y>/%<%m>/%<%Y-%m-%d>.org",
            template = [[
* Daily Log
  :PROPERTIES:
  :CATEGORY: Daily
  :END:
** 📋 昨日回顾 (Yesterday)

** 🎯 今日核心目标 (Today)

** 🚧 风险与阻塞 (Blockers)

** 📥 Task

** 📋 记录 (Record)
]],
          },
          -- 日记模板：实现 ~/org/gtd/年/月/年-月-日.org
          j = {
            description = "Daily Journal",
            template = "\n*** %<%H:%M> 记录\n%?",
            -- 关键：通过时间格式化构建深层目录
            -- %<%Y> 是年，%<%m> 是月，%<%Y-%m-%d> 是文件名
            target = "~/org/gtd/%<%Y>/%<%m>/%<%Y-%m-%d>.org",
          },

          -- 4. 灵感/闪念 (Inbox) - 最简化的记录
          i = {
            description = "瞬时灵感",
            template = "* %?\n  %U", -- %U 是带精确时间的戳
            target = "~/org/inbox.org",
          },
        },
        mappings = {
          org = {
            -- 将切换 Checkbox 的快捷键改为 <Leader>cc (或者你可以改成 <CR> 回车键)
            org_toggle_checkbox = "<Leader>o<Space>",
          },
        },
        -- org_archive_location = "#+ARCHIVE: ~/org/archive/%s_archive::",
      })

      require("org-bullets").setup()

      require("blink.cmp").setup({
        sources = {
          per_filetype = {
            org = { "orgmode" },
          },
          providers = {
            orgmode = {
              name = "Orgmode",
              module = "orgmode.org.autocompletion.blink",
              fallbacks = { "buffer" },
            },
          },
        },
      })
    end,
  },
  {
    "nvim-orgmode/telescope-orgmode.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-orgmode/orgmode",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").load_extension("orgmode")
    end,
    keys = {
      {
        "<leader>oR",
        function()
          require("telescope").extensions.orgmode.refile_heading()
        end,
        desc = "Refile heading",
      },
      {
        "<leader>of",
        function()
          require("telescope").extensions.orgmode.search_headings()
        end,
        desc = "Search headings",
      },
      {
        "<leader>olI",
        function()
          require("telescope").extensions.orgmode.insert_link()
        end,
        desc = "Telescope Insert link",
      },
      {
        "<leader>ost",
        function()
          require("telescope").extensions.orgmode.search_tags()
        end,
        desc = "Search tags",
      },
    },
  },
  {
    "chipsenkbeil/org-roam.nvim",
    tag = "0.2.0",
    ft = { "org" },
    dependencies = {
      {
        "nvim-orgmode/orgmode",
        tag = "0.7.0",
      },
    },
    config = function()
      require("org-roam").setup({
        directory = "~/org/notes",
        bindings = {
          prefix = "<Leader>j",
        },
      })
    end,
  },
  -- {
  --   "hamidi-dev/org-list.nvim",
  --   dependencies = {
  --     "tpope/vim-repeat", -- for repeatable actions with '.'
  --   },
  --   config = function()
  --     require("org-list").setup({
  --       mapping = {
  --         key = "<leader>lt", -- nvim-orgmode users: you might want to change this to <leader>olt
  --         desc = "Toggle: Cycle through list types",
  --       },
  --       checkbox_toggle = {
  --         enabled = true,
  --         -- NOTE: for nvim-orgmode users, you should change the following mapping OR change the one from orgmode.
  --         -- If both mapping stay the same, the one from nvim-orgmode will "win"
  --         key = "<C-1>",
  --         desc = "Toggle checkbox state",
  --         filetypes = { "org", "markdown" }, -- Add more filetypes as needed
  --       },
  --     })
  --   end,
  -- },
  -- {
  --   "massix/org-checkbox.nvim",
  --   config = function()
  --     require("orgcheckbox").setup()
  --   end,
  --   ft = { "org" },
  -- },
  -- {
  --   "michhernand/RLDX.nvim",
  --   event = "VeryLazy",
  --   dependencies = {},
  --   opts = {
  --     filename = { os.getenv("HOME") .. "/.config/.rolodex/db.json" },
  --   },
  --   keys = {
  --     { "<leader>Xa", "<cmd>RldxAdd<CR>" },
  --     { "<leader>Xl", "<cmd>RldxLoad<CR>" },
  --     { "<leader>Xs", "<cmd>RldxSave<CR>" },
  --     { "<leader>Xd", "<cmd>RldxDelete<CR>" },
  --     { "<leader>Xp", "<cmd>RldxProps<CR>" },
  --   },
  -- },
  -- {
  --   "hamidi-dev/org-super-agenda.nvim",
  --   dependencies = {
  --     "nvim-orgmode/orgmode", -- required
  --     { "lukas-reineke/headlines.nvim", config = true }, -- optional nicety
  --   },
  --   config = function()
  --     require("org-super-agenda").setup({
  --       org_directories = { "~/org/" },
  --
  --       todo_states = {
  --         {
  --           name = "TODO",
  --           keymap = "ot",
  --           color = "#E8706F",
  --           strike_through = false,
  --           fields = { "filename", "todo", "headline", "priority", "date", "tags" },
  --         },
  --         {
  --           name = "PROGRESS",
  --           keymap = "op",
  --           color = "#F5A623",
  --           strike_through = false,
  --           fields = { "filename", "todo", "headline", "priority", "date", "tags" },
  --         },
  --         {
  --           name = "WAITING",
  --           keymap = "ow",
  --           color = "#9D7FB3",
  --           strike_through = false,
  --           fields = { "filename", "todo", "headline", "priority", "date", "tags" },
  --         },
  --         {
  --           name = "DONE",
  --           keymap = "od",
  --           color = "#52C0A1",
  --           strike_through = true,
  --           fields = { "filename", "todo", "headline", "priority", "date", "tags" },
  --         },
  --       },
  --
  --       -- Agenda keymaps (inline comments explain each)
  --       keymaps = {
  --         filter_reset = "oa", -- reset all filters
  --         toggle_other = "oo", -- toggle catch-all "Other" section
  --         filter = "of", -- live filter (exact text)
  --         filter_fuzzy = "oz", -- live filter (fuzzy)
  --         filter_query = "oq", -- advanced query input
  --         undo = "u", -- undo last change
  --         reschedule = "cs", -- set/change SCHEDULED
  --         set_deadline = "cd", -- set/change DEADLINE
  --         cycle_todo = "t", -- cycle TODO state
  --         set_state = "s", -- set state directly (st, sd, etc.) or show menu
  --         reload = "r", -- refresh agenda
  --         refile = "R", -- refile via Telescope/org-telescope
  --         hide_item = "x", -- hide current item
  --         preview = "K", -- preview headline content
  --         reset_hidden = "X", -- clear hidden list
  --         toggle_duplicates = "D", -- duplicate items may appear in multiple groups
  --         cycle_view = "ov", -- switch view (classic/compact)
  --       },
  --
  --       -- Window/appearance
  --       window = {
  --         width = 0.8,
  --         height = 0.7,
  --         border = "rounded",
  --         title = "Org Super Agenda",
  --         title_pos = "center",
  --         margin_left = 0,
  --         margin_right = 0,
  --         fullscreen_border = "none", -- border style when using fullscreen
  --       },
  --
  --       -- Group definitions (order matters; first match wins unless allow_duplicates=true)
  --       groups = {
  --         {
  --           name = "📅 今天",
  --           matcher = function(i)
  --             return i.scheduled and i.scheduled:is_today()
  --           end,
  --           sort = { by = "priority", order = "desc" },
  --         },
  --         {
  --           name = "🗓️ Tomorrow",
  --           matcher = function(i)
  --             return i.scheduled and i.scheduled:days_from_today() == 1
  --           end,
  --         },
  --         {
  --           name = "☠️ Deadlines",
  --           matcher = function(i)
  --             return i.deadline and i.todo_state ~= "DONE" and not i:has_tag("personal")
  --           end,
  --           sort = { by = "deadline", order = "asc" },
  --         },
  --         {
  --           name = "⭐ Important",
  --           matcher = function(i)
  --             return i.priority == "A" and (i.deadline or i.scheduled)
  --           end,
  --           sort = { by = "date_nearest", order = "asc" },
  --         },
  --         {
  --           name = "⏳ Overdue",
  --           matcher = function(i)
  --             return i.todo_state ~= "DONE"
  --               and ((i.deadline and i.deadline:is_past()) or (i.scheduled and i.scheduled:is_past()))
  --           end,
  --           sort = { by = "date_nearest", order = "asc" },
  --         },
  --         {
  --           name = "🏠 Personal",
  --           matcher = function(i)
  --             return i:has_tag("personal")
  --           end,
  --         },
  --         {
  --           name = "💼 Work",
  --           matcher = function(i)
  --             return i:has_tag("work")
  --           end,
  --         },
  --         {
  --           name = "📆 Upcoming",
  --           matcher = function(i)
  --             local days = require("org-super-agenda.config").get().upcoming_days or 10
  --             local d1 = i.deadline and i.deadline:days_from_today()
  --             local d2 = i.scheduled and i.scheduled:days_from_today()
  --             return (d1 and d1 >= 0 and d1 <= days) or (d2 and d2 >= 0 and d2 <= days)
  --           end,
  --           sort = { by = "date_nearest", order = "asc" },
  --         },
  --       },
  --
  --       -- Defaults & behavior
  --       upcoming_days = 10,
  --       hide_empty_groups = true, -- drop blank sections
  --       keep_order = false, -- keep original org order (rarely useful)
  --       allow_duplicates = false, -- if true, an item can live in multiple groups
  --       group_format = "* %s", -- group header format
  --       other_group_name = "Other",
  --       show_other_group = false, -- show catch-all section
  --       show_tags = true, -- draw tags on the right
  --       show_filename = true, -- include [filename]
  --       heading_max_length = 70,
  --       persist_hidden = false, -- keep hidden items across reopen
  --       view_mode = "classic", -- 'classic' | 'compact'
  --
  --       classic = {
  --         heading_order = { "filename", "todo", "priority", "headline" },
  --         short_date_labels = false,
  --         inline_dates = true,
  --       },
  --       compact = { filename_min_width = 10, label_min_width = 12 },
  --
  --       -- Global fallback sort for groups that omit `sort`
  --       group_sort = { by = "date_nearest", order = "asc" },
  --
  --       -- Popup mode: run in a persistent tmux session for instant access
  --       popup_mode = {
  --         enabled = false,
  --         hide_command = nil, -- e.g., "tmux detach-client"
  --       },
  --
  --       debug = false,
  --     })
  --   end,
  -- },
}
