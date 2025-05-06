return {
  {
    "obsidian-nvim/obsidian.nvim",
    -- version = "*", -- recommended, use latest release instead of latest commit
    version = false,
    lazy = true,
    ft = "markdown",
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "saghen/blink.cmp",
      "MeanderingProgrammer/render-markdown.nvim",
      -- see below for full list of optional dependencies 👇
    },
    opts = {
      workspaces = {
        {
          name = "personal",
          path = "~/vaults/personal",
        },
      },
      notes_subdir = "",

      daily_notes = {
        -- Optional, if you keep daily notes in a separate directory.
        folder = "0.周期笔记/dailies",
        -- Optional, if you want to change the date format for the ID of daily notes.
        date_format = "%Y-%m-%d",
        -- Optional, if you want to change the date format of the default alias of daily notes.
        alias_format = "%B %-d, %Y",
        -- Optional, default tags to add to each new daily note created.
        default_tags = { "daily-notes" },
        -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
        template = "daily.md",
      },

      -- 补全
      completion = {
        -- nvim_cmp = true,
        -- Set to false to disable completion.
        blink = true,
        -- Trigger completion at 2 chars.
        min_chars = 2,
      },

      -- Where to put new notes. Valid options are
      --  * "current_dir" - put new notes in same directory as the current buffer.
      --  * "notes_subdir" - put new notes in the default notes subdirectory.
      -- new_notes_location = "current_dir",
      -- Optional, customize how note IDs are generated given an optional title.

      ---@param title string|?
      ---@return string
      note_id_func = function(title)
        -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
        -- In this case a note with the title 'My new note' will be given an ID that looks
        -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
        local suffix = ""
        if title ~= nil then
          -- If title is given, transform it into valid file name.
          suffix = title:gsub(" ", "-"):lower()
        else
          -- If title is nil, just add 4 random uppercase letters to the suffix.
          for _ = 1, 4 do
            suffix = suffix .. string.char(math.random(65, 90))
          end
        end
        return suffix
      end,

      -- Optional, by default when you use `:ObsidianFollowLink` on a link to an external
      -- URL it will be ignored but you can customize this behavior here.
      ---@param url string
      follow_url_func = function(url)
        -- Open the URL in the default web browser.
        vim.fn.jobstart({ "open", url }) -- Mac OS
        -- vim.fn.jobstart({"xdg-open", url})  -- linux
        -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
        -- vim.ui.open(url) -- need Neovim 0.10.0+
      end,

      -- Optional, customize how wiki links are formatted. You can set this to one of:
      --  * "use_alias_only", e.g. '[[Foo Bar]]'
      --  * "prepend_note_id", e.g. '[[foo-bar|Foo Bar]]'
      --  * "prepend_note_path", e.g. '[[foo-bar.md|Foo Bar]]'
      --  * "use_path_only", e.g. '[[foo-bar.md]]'
      -- Or you can set it to a function that takes a table of options and returns a string, like this:
      -- wiki_link_func = function(opts)
      --   return require("obsidian.util").wiki_link_id_prefix(opts)
      -- end,
      preferred_link_style = "wiki",

      disable_frontmatter = false,

      templates = {
        folder = "templates",
        date_format = "%Y-%m-%d",
        time_format = "%H:%M",
        -- A map for custom variables, the key should be the variable and the value a function
        substitutions = {},
      },

      open_app_foreground = false,

      ui = {
        enable = false, -- set to false to disable all additional syntax features
        -- update_debounce = 200, -- update delay after a text change (in milliseconds)
        -- max_file_length = 5000, -- disable UI features for files with more than this many lines
        -- Define how various check-boxes are displayed
        checkboxes = {
          -- NOTE: the 'char' value has to be a single character, and the highlight groups are defined below.
          -- [" "] = { char = "󰄱", hl_group = "ObsidianTodo" },
          -- ["x"] = { char = "", hl_group = "ObsidianDone" },
          -- [">"] = { char = "", hl_group = "ObsidianRightArrow" },
          -- ["~"] = { char = "󰰱", hl_group = "ObsidianTilde" },
          -- ["!"] = { char = "", hl_group = "ObsidianImportant" },
          -- Replace the above with this if you don't have a patched font:
          [" "] = { char = "☐", hl_group = "ObsidianTodo" },
          ["x"] = { char = "✔", hl_group = "ObsidianDone" },

          -- You can also add more custom ones...
        },
        -- -- Use bullet marks for non-checkbox lists.
        -- bullets = { char = "•", hl_group = "ObsidianBullet" },
        -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
        -- -- Replace the above with this if you don't have a patched font:
        -- -- external_link_icon = { char = "", hl_group = "ObsidianExtLinkIcon" },
        -- reference_text = { hl_group = "ObsidianRefText" },
        -- highlight_text = { hl_group = "ObsidianHighlightText" },
        -- tags = { hl_group = "ObsidianTag" },
        -- block_ids = { hl_group = "ObsidianBlockID" },
        -- hl_groups = {
        --   -- The options are passed directly to `vim.api.nvim_set_hl()`. See `:help nvim_set_hl`.
        --   ObsidianTodo = { bold = true, fg = "#f78c6c" },
        --   ObsidianDone = { bold = true, fg = "#89ddff" },
        --   ObsidianRightArrow = { bold = true, fg = "#f78c6c" },
        --   ObsidianTilde = { bold = true, fg = "#ff5370" },
        --   ObsidianImportant = { bold = true, fg = "#d73128" },
        --   ObsidianBullet = { bold = true, fg = "#89ddff" },
        --   ObsidianRefText = { underline = true, fg = "#c792ea" },
        --   ObsidianExtLinkIcon = { fg = "#c792ea" },
        --   ObsidianTag = { italic = true, fg = "#89ddff" },
        --   ObsidianBlockID = { italic = true, fg = "#89ddff" },
        --   ObsidianHighlightText = { bg = "#75662e" },
        -- },
      },

      -- Specify how to handle attachments.
      attachments = {
        -- The default folder to place images in via `:ObsidianPasteImg`.
        -- If this is a relative path it will be interpreted as relative to the vault root.
        -- You can always override this per image by passing a full path to the command instead of just a filename.
        img_folder = "assets/imgs", -- This is the default

        -- Optional, customize the default name or prefix when pasting images via `:ObsidianPasteImg`.
        ---@return string
        img_name_func = function()
          -- Prefix image names with timestamp.
          return string.format("%s-", os.time())
        end,

        -- A function that determines the text to insert in the note when pasting an image.
        -- It takes two arguments, the `obsidian.Client` and an `obsidian.Path` to the image file.
        -- This is the default implementation.
        ---@param client obsidian.Client
        ---@param path obsidian.Path the absolute path to the image file
        ---@return string
        img_text_func = function(client, path)
          path = client:vault_relative_path(path) or path
          return string.format("![%s](%s)", path.name, path)
        end,
      },
    },
  },

  {
    -- "atiladefreitas/dooing",
    dir = "~/.config/nvim/clone/dooing",
    config = function()
      require("dooing").setup({
        -- your custom config here (optional)
        save_path = "/Users/zhoushitie/vaults/personal/.todos.json",
        -- save_path = "/Users/zhoushitie/.config/nvim/todos.json",

        -- Timestamp settings
        timestamp = {
          enabled = true, -- Show relative timestamps (e.g., @5m ago, @2h ago)
        },

        -- Window settings
        window = {
          width = 100, -- Width of the floating window
          height = 15, -- Height of the floating window
          border = "rounded", -- Border style
          position = "center", -- Window position: 'right', 'left', 'top', 'bottom', 'center',
          -- 'top-right', 'top-left', 'bottom-right', 'bottom-left'
          padding = {
            top = 1,
            bottom = 1,
            left = 2,
            right = 2,
          },
        },

        done_sort_by_completed_time = true,

        -- To-do formatting
        formatting = {
          pending = {
            icon = "○",
            format = { "icon", "notes_icon", "text", "due_date", "ect" },
          },
          in_progress = {
            icon = "◐",
            format = { "icon", "text", "due_date", "ect" },
          },
          done = {
            icon = "✓",
            format = { "icon", "notes_icon", "text", "due_date", "ect" },
          },
        },

        quick_keys = true, -- Quick keys window

        notes = {
          icon = "📓",
        },

        scratchpad = {
          syntax_highlight = "markdown",
        },

        -- Keymaps
        keymaps = {
          toggle_window = "<leader>td",
          new_todo = "i",
          toggle_todo = "x",
          delete_todo = "d",
          delete_completed = "D",
          close_window = "q",
          undo_delete = "u",
          add_due_date = "H",
          remove_due_date = "r",
          toggle_help = "?",
          toggle_tags = "t",
          toggle_priority = "<Space>",
          clear_filter = "c",
          edit_todo = "e",
          edit_tag = "e",
          edit_priorities = "p",
          delete_tag = "d",
          search_todos = "/",
          add_time_estimation = "T",
          remove_time_estimation = "R",
          import_todos = "I",
          export_todos = "E",
          remove_duplicates = "<leader>D",
          open_todo_scratchpad = "<leader>p",
          refresh_todos = "F",
        },

        calendar = {
          language = "en",
          icon = "",
          keymaps = {
            previous_day = "h",
            next_day = "l",
            previous_week = "k",
            next_week = "j",
            previous_month = "H",
            next_month = "L",
            select_day = "<CR>",
            close_calendar = "q",
          },
        },

        -- Priority settings
        priorities = {
          {
            name = "urgent",
            weight = 8,
          },
          {
            name = "important",
            weight = 4,
          },
          {
            name = "trivial",
            weight = 2,
          },
          {
            name = "future",
            weight = -1,
          },
        },
        priority_groups = {
          high = {
            members = { "urgent" },
            color = nil, -- 红色
            hl_group = "DiagnosticError",
          },
          medium = {
            members = { "important" },
            color = nil, -- 橙色
            hl_group = "DiagnosticWarn",
          },
          trivial = {
            members = { "trivial" },
            color = nil, -- 蓝色
            hl_group = "DiagnosticInfo",
          },
          low = {
            members = { "future" },
            color = "#89CFF0",
          },
        },
        hour_score_value = 1 / 8,
      })
    end,
  },

  {
    "lfilho/note2cal.nvim",
    config = function()
      require("note2cal").setup({
        debug = false, -- if true, prints a debug message an return early (won't schedule events)
        calendar_name = "zhouatie@gmail.com", -- the name of the calendar as it appear on Calendar.app
        highlights = {
          at_symbol = "WarningMsg", -- the highlight group for the "@" symbol
          at_text = "Number", -- the highlight group for the date-time part
        },
        keymaps = {
          normal = "<Leader>se", -- mnemonic: Schedule Event
          visual = "<Leader>se", -- mnemonic: Schedule Event
        },
      })
    end,
    ft = "markdown",
  },

  {
    "jbyuki/venn.nvim",
  },
}
