-- 加载 Obsidian 相关快捷键配置
-- require("config.obsidian-keymap").setup()

-- 禁止markdown txt 检查贫血
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "txt" },
  callback = function()
    vim.opt_local.spell = false
  end,
})
