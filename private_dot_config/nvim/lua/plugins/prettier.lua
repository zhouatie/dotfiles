return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function()
      -- 检查项目目录是否存在 Prettier 配置文件
      local prettier_config_files = {
        ".prettierrc",
        ".prettierrc.json",
        ".prettierrc.yml",
        ".prettierrc.yaml",
        ".prettierrc.js",
        ".prettierrc.cjs",
        "prettier.config.js",
        "prettier.config.cjs",
        ".prettierrc.toml",
        "prettier.config.mjs",
      }

      local function find_project_prettier_config()
        local cwd = vim.fn.getcwd()
        for _, file in ipairs(prettier_config_files) do
          local config_path = cwd .. "/" .. file
          if vim.fn.filereadable(config_path) == 1 then
            return true
          end
        end
        return false
      end

      local has_project_config = find_project_prettier_config()
      local fallback_config = vim.fn.expand("~/.config/nvim/.prettierrc.json")

      return {
        formatters = {
          prettierd = {
            -- 如果项目没有配置，则使用全局配置
            prepend_args = has_project_config and {} or { "--config", fallback_config },
          },
          prettier = {
            -- 如果项目没有配置，则使用全局配置
            prepend_args = has_project_config and {} or { "--config", fallback_config },
          },
        },
        formatters_by_ft = {
          javascript = { "prettierd", "eslint_d" },
          ["javascriptreact"] = { "prettierd", "eslint_d" },
          ["typescript"] = { "prettierd", "eslint_d" },
          ["typescriptreact"] = { "prettierd", "eslint_d" },
          ["vue"] = { "prettierd", "eslint_d" },
          ["css"] = { "prettierd", "eslint_d" },
          ["scss"] = { "prettierd", "eslint_d" },
          ["sass"] = { "prettierd", "eslint_d" },
          ["less"] = { "prettierd", "eslint_d" },
          ["html"] = { "prettierd", "eslint_d" },
          ["json"] = { "prettierd" },
          ["jsonc"] = { "prettierd" },
          ["yaml"] = { "prettierd" },
          -- ["markdown"] = { "prettier" },
          -- ["markdown.mdx"] = { "prettier" },
          ["graphql"] = { "prettierd", "eslint_d" },
          ["handlebars"] = { "prettierd", "eslint_d" },
          ["toml"] = { "prettierd" },
          ["lua"] = { "stylua" },
        },
      }
    end,
  },
}
