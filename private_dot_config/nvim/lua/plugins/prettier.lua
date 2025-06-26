return {
  {
    "stevearc/conform.nvim",
    lazy = false,
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- 设置全局格式化参数，确保使用异步模式 (使用新的配置选项)
      opts.default_format_opts = vim.tbl_deep_extend("force", opts.default_format_opts or {}, {
        async = true,
        timeout_ms = 3000,
        lsp_fallback = true,
      })

      -- 定义我们要自定义的文件类型格式化器
      local custom_formatters_by_ft = {
        javascript = { "prettierd", "eslint_d" },
        ["javascriptreact"] = { "prettierd", "eslint_d" },
        ["typescript"] = { "prettierd", "eslint_d" },
        ["typescriptreact"] = { "prettierd", "eslint_d" },
        ["vue"] = { "prettierd", "eslint_d" },
        ["css"] = { "prettierd", "eslint_d" },
        ["scss"] = { "prettierd", "eslint_d" },
        ["sass"] = { "prettierd", "eslint_d" },
        ["less"] = { "prettierd", "eslint_d" },
        ["html"] = { "prettierd" },
        ["json"] = { "prettier" },
        ["jsonc"] = { "prettier" },
        ["yaml"] = { "prettierd" },
        -- ["markdown"] = { "prettier" },
        -- ["markdown.mdx"] = { "prettier" },
        ["graphql"] = { "prettierd", "eslint_d" },
        ["handlebars"] = { "prettierd", "eslint_d" },
        ["toml"] = { "prettierd" },
        ["lua"] = { "stylua" },
        python = { "isort", "black" },
      }

      -- 合并我们的自定义配置与现有配置
      for ft, formatters in pairs(custom_formatters_by_ft) do
        opts.formatters_by_ft[ft] = formatters
      end

      return opts
    end,
  },
}
