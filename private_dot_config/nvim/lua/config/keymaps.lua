-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    if opts.remap and not vim.g.vscode then
      opts.remap = nil
    end
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

map("i", "jk", "<Esc>", { desc = "to normal mode" })
map({ "i" }, "jkl", "<cmd>w<cr><esc>", { desc = "save" })

-- Obsidian 任务收集器配置
local collect_tasks = require("utils.collect_tasks")

-- 创建命令
vim.api.nvim_create_user_command("ObsidianCollectTasks", function()
  collect_tasks.collect_and_update_dashboard()
end, {
  desc = "收集Obsidian vault中所有未完成任务并更新到dashboard.md",
})

-- 设置快捷键
vim.keymap.set(
  "n",
  "<Leader>ot",
  ":ObsidianCollectTasks<CR>",
  { noremap = true, silent = true, desc = "收集Obsidian中未完成任务" }
)
