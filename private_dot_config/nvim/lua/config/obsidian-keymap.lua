-- Obsidian 相关快捷键配置
local M = {}

function M.setup()
  -- Obsidian 任务收集器配置
  -- local collect_tasks = require("utils.collect_tasks") // FIXME: 如果不用了，就删除

  -- 创建命令
  -- vim.api.nvim_create_user_command("ObsidianCollectTasks", function()
  --   collect_tasks.collect_and_update_dashboard()
  -- end, {
  --   desc = "收集Obsidian vault中所有未完成任务并更新到dashboard.md",
  -- })

  -- 设置快捷键
  -- vim.keymap.set(
  --   "n",
  --   "<Leader>ot",
  --   ":ObsidianCollectTasks<CR>",
  --   { noremap = true, silent = true, desc = "收集Obsidian中未完成任务" }
  -- )

  local map = vim.keymap.set

  -- <leader>o prefix for all Obsidian commands

  -- Commands that might need parameters
  map("n", "<leader>on", function()
    vim.ui.input({ prompt = "Note title: " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianNew " .. input)
      else
        vim.cmd("ObsidianNew")
      end
    end)
  end, { desc = "新建笔记" })

  map("n", "<leader>ot", function()
    vim.ui.input({ prompt = "Template name: " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianTemplate " .. input)
      else
        vim.cmd("ObsidianTemplate")
      end
    end)
  end, { desc = "插入模板" })

  -- Commands without parameters or optional parameters
  -- map("n", "<leader>od", "<cmd>ObsidianToday<cr>", { desc = "打开今日笔记" })

  map("n", "<leader>od", function()
    vim.ui.input({ prompt = "offset: " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianToday " .. input)
      else
        vim.cmd("ObsidianToday")
      end
    end)
  end, { desc = "打开今日笔记" })

  map("n", "<leader>os", function()
    vim.ui.input({ prompt = "Search query (optional): " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianSearch " .. input)
      else
        vim.cmd("ObsidianSearch")
      end
    end)
  end, { desc = "搜索笔记" })

  map("n", "<leader>ol", function()
    vim.ui.input({ prompt = "Link query (optional): " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianLink " .. input)
      else
        vim.cmd("ObsidianLink")
      end
    end)
  end, { desc = "添加链接" })

  map("v", "<leader>ol", ":'<,'>ObsidianLink<cr>", { desc = "为选中文本添加链接" })
  map("n", "<leader>ob", "<cmd>ObsidianLinks<cr>", { desc = "显示反向链接" })

  map("n", "<leader>ow", function()
    vim.ui.input({ prompt = "Workspace name (optional): " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianWorkspace " .. input)
      else
        vim.cmd("ObsidianWorkspace")
      end
    end)
  end, { desc = "切换工作区" })

  map("n", "<leader>op", function()
    vim.ui.input({ prompt = "Image name (optional): " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianPasteImg " .. input)
      else
        vim.cmd("ObsidianPasteImg")
      end
    end)
  end, { desc = "粘贴图片" })

  map("n", "<leader>oN", function()
    vim.ui.input({ prompt = "New note title: " }, function(title)
      if title and title ~= "" then
        vim.cmd("ObsidianNewFromTemplate " .. title)
      else
        vim.cmd("ObsidianNewFromTemplate")
      end
    end)
  end, { desc = "从模板新建笔记" })

  map("n", "<leader>oc", "<cmd>ObsidianTOC<cr>", { desc = "TOC" })

  -- Quick note switching
  map("n", "<leader>of", "<cmd>ObsidianQuickSwitch<cr>", { desc = "快速切换笔记" })

  -- Additional useful commands
  map("n", "<leader>obt", "<cmd>ObsidianBacklinks<cr>", { desc = "查找反向链接" })
  map("n", "<leader>ot", function()
    vim.ui.input({ prompt = "Tag(s) to search: " }, function(input)
      if input and input ~= "" then
        vim.cmd("ObsidianTags " .. input)
      else
        vim.cmd("ObsidianTags")
      end
    end)
  end, { desc = "搜索标签" })

  map("n", "<leader>ovs", function()
    vim.cmd("ObsidianFollowLink vsplit")
  end, { desc = "在垂直分屏中打开链接" })

  map("n", "<leader>ohs", function()
    vim.cmd("ObsidianFollowLink hsplit")
  end, { desc = "在水平分屏中打开链接" })

  map("n", "<leader>oex", function()
    vim.ui.input({ prompt = "Extract note title: " }, function(input)
      if input and input ~= "" then
        vim.cmd("'<,'>ObsidianExtractNote " .. input)
      else
        vim.cmd("'<,'>ObsidianExtractNote")
      end
    end)
  end, { desc = "提取选中内容到新笔记" })
end

return M
