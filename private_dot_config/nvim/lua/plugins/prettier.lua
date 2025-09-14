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

      -- 配置只使用 eslint_d 的工程名称（可以添加多个）
      local eslint_only_projects = {
        "pc%-html", -- 使用 Lua 模式匹配，- 需要转义为 %-
        -- "other%-project",  -- 可以添加其他需要限制的工程
      }

      for _, filetype in ipairs(prettier_eslint_filetypes) do
        local cwd = vim.fn.getcwd()
        local use_eslint_only = false

        -- 检查当前目录是否匹配配置的工程名
        for _, project_pattern in ipairs(eslint_only_projects) do
          if string.match(cwd, project_pattern) then
            use_eslint_only = true
            break
          end
        end

        if use_eslint_only then
          custom_formatters_by_ft[filetype] = { "eslint_d" }
        else
          custom_formatters_by_ft[filetype] = { "prettier", "eslint_d" }
        end
      end

      -- 合并我们的自定义配置与现有配置
      for ft, formatters in pairs(custom_formatters_by_ft) do
        opts.formatters_by_ft[ft] = formatters
      end

      return opts
    end,
  },
}
