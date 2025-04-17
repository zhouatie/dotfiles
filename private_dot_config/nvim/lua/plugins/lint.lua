return {
  "mfussenegger/nvim-lint",
  optional = true,
  opts = {
    -- 禁用 markdown 文件的 lint 检查
    linters_by_ft = {
      markdown = {}, -- 空数组表示禁用 markdown 的 lint
    },
  },
}
