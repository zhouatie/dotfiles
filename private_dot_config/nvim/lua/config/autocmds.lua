-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.opt.laststatus = 3

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("disable_spell_in_text_files", { clear = true }),
  pattern = { "markdown", "markdown.mdx", "text" },
  callback = function()
    vim.opt_local.spell = false
  end,
})
