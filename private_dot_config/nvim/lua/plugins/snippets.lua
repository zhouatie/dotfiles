-- 扩展 mini.snippets 配置，支持多个配置文件加载
local gen_loader = require("mini.snippets").gen_loader

-- 文件类型和配置文件的映射关系
-- 每个文件类型对应一个模式数组，支持灵活组合
local lang_patterns = {
  org = {
    "org.json",
  },
  typescript = {
    "javascript.json",
    "react-native.json",
    "typescript.json",
    "javascriptreact.json",
    "typescriptreact.json",
  },
  typescriptreact = {
    "javascript.json",
    "react-native.json",
    "typescript.json",
    "javascriptreact.json",
    "typescriptreact.json",
  },
  tsx = {
    "javascript.json",
    "react-native.json",
    "typescript.json",
    "javascriptreact.json",
    "typescriptreact.json",
  },
  jsx = {
    "javascript.json",
    "react-native.json",
    "typescript.json",
    "javascriptreact.json",
    "typescriptreact.json",
  },
  markdown_inline = {
    "markdown.json",
  },
  comment = {
    "comment.json",
  },
  -- 可继续添加其他文件类型
}

return {
  {
    "nvim-mini/mini.snippets",
    opts = {
      snippets = {
        -- 全局 snippets（所有文件类型都加载）
        gen_loader.from_file(vim.fn.stdpath("config") .. "/snippets/global.json"),

        -- 根据文件类型加载对应的配置文件组合
        gen_loader.from_lang({
          lang_patterns = lang_patterns,
        }),
      },

      mappings = {
        expand = "<C-j>",
        jump_next = "<C-l>",
        jump_prev = "<C-h>",
        stop = "<Esc>",
      },

      expand = {
        prepare = nil,
        match = nil,
        select = nil,
        insert = nil,
      },
    },
  },
}
