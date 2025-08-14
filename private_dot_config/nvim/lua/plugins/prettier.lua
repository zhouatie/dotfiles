return {
  {
    "stevearc/conform.nvim",
    lazy = true,
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      -- 定义我们要自定义的文件类型格式化器
      local custom_formatters_by_ft = {
        ["toml"] = { "taplo" },
        ["lua"] = { "stylua" },
        python = { "isort", "black" },
      }

      -- 为支持 prettier + eslint_d 的文件类型统一设置
      local prettier_eslint_filetypes = {
        "javascriptreact",
        "typescript",
        "javascript",
        "typescriptreact",
        "vue",
        "css",
        "scss",
        "sass",
        "less",
        "html",
        -- "json",
        -- "jsonc",
        "yaml",
        "graphql",
        "handlebars",
      }

      for _, filetype in ipairs(prettier_eslint_filetypes) do
        custom_formatters_by_ft[filetype] = { "prettier", "eslint_d" }
      end

      -- 合并我们的自定义配置与现有配置
      for ft, formatters in pairs(custom_formatters_by_ft) do
        opts.formatters_by_ft[ft] = formatters
      end

      return opts
    end,
  },
}
