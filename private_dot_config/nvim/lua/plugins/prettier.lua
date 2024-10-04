return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {

      formatters_by_ft = {
        ["javascript"] = { "eslint_d" },
        ["javascriptreact"] = { "eslint_d" },
        ["typescript"] = { "eslint_d" },
        ["typescriptreact"] = { "eslint_d" },
        ["vue"] = { "eslint_d" },
        ["css"] = { "prettier", "stylelint" },
        ["scss"] = { "prettier", "stylelint" },
        ["less"] = { "prettier", "stylelint" },
        ["html"] = { "prettier" },
        ["json"] = { "prettier" },
        ["jsonc"] = { "prettier" },
        ["yaml"] = { "prettier" },
        ["markdown"] = { "prettier" },
        ["markdown.mdx"] = { "prettier" },
        ["graphql"] = { "prettier" },
        ["handlebars"] = { "prettier" },
      },
    },
  },
}
