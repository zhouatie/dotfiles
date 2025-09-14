-- Python Provider 配置
require("config.python_provider")

-- 自动处理交换文件冲突
vim.api.nvim_create_autocmd("SwapExists", {
  callback = function()
    vim.v.swapchoice = "e"  -- 自动选择 "edit anyway"
  end,
})

-- 设置 shortmess 选项来抑制 ATTENTION 消息
vim.opt.shortmess:append("A")

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
