return {
  "obsidian-nvim/obsidian.nvim",
  version = "*", -- use latest release, remove to use latest commit
  ft = "markdown",
  opts = {
    legacy_commands = false, -- this will be removed in the next major release

    workspaces = {
      {
        name = "personal",
        path = "~/vaults/personal",
      },
    },

    templates = {
      folder = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      -- A map for custom variables, the key should be the variable and the value a function
      substitutions = {},
    },

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

    completion = {
      nvim_cmp = false,
      blink = true,
      min_chars = 2,
    },

    attachments = {
      folder = "assets/imgs",

      img_text_func = function(path)
        local name = vim.fs.basename(tostring(path))
        local encoded_name = require("obsidian.util").urlencode(name)
        return string.format("![%s](~/vaults/personal/assets/imgs/%s)", name, encoded_name)
      end,
    },

    picker = {
      name = "snacks.pick",
      note_mappings = {
        -- Create a new note from your query.
        new = "<C-x>",
        -- Insert a link to the selected note.
        insert_link = "<C-l>",
      },
      tag_mappings = {
        -- Add tag(s) to current note.
        tag_note = "<C-x>",
        -- Insert a tag at the current location.
        insert_tag = "<C-l>",
      },
    },

    checkbox = {
      order = { " ", "x" },
    },

    ui = { enable = false },

    preferred_link_style = "markdown",
  },
  config = function(_, opts)
    require("obsidian").setup(opts)
  end,
}
