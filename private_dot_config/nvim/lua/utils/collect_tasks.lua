-- collect_tasks.lua
-- 脚本用于收集Obsidian vault中所有未完成任务并更新到dashboard.md

-- 导入必要的库
local scan = require("plenary.scandir")
local Path = require("plenary.path")

-- 定义Obsidian vault根目录
local vault_dir = vim.fn.expand("~/vaults/personal")

print("Obsidian vault目录: " .. vault_dir)

-- 定义dashboard文件路径
local dashboard_path = Path:new(vault_dir, "dashboard.md")

-- 配置：要忽略的目录列表
local ignored_dirs = {
  "templates/", -- 忽略templates目录
}

-- 函数：收集所有未完成的任务
local function collect_uncompleted_tasks()
  local tasks = {}

  -- 查找所有markdown文件
  local markdown_files = scan.scan_dir(vault_dir, {
    search_pattern = "%.md$",
    respect_gitignore = true,
    depth = 10, -- 递归搜索深度
    silent = true,
  })

  -- 遍历所有markdown文件
  for _, file_path in ipairs(markdown_files) do
    local rel_path = Path:new(file_path):make_relative(vault_dir)

    -- 检查是否应该忽略该文件
    local should_ignore = false
    if rel_path == "dashboard.md" then
      should_ignore = true
    else
      for _, ignored_dir in ipairs(ignored_dirs) do
        if rel_path:match("^" .. ignored_dir) then
          should_ignore = true
          break
        end
      end
    end

    if not should_ignore then
      -- 读取文件内容
      local file = io.open(file_path, "r")
      if file then
        local line_num = 0
        local found_tasks = false
        local file_tasks = {}

        -- 逐行读取文件内容
        for line in file:lines() do
          line_num = line_num + 1

          -- 查找未完成任务 "- [ ]"
          if line:match("^%s*%-%s*%[%s%]") then
            found_tasks = true
            table.insert(file_tasks, {
              line = line,
              line_num = line_num,
            })
          end
        end

        file:close()

        -- 如果文件中有未完成任务，添加到任务列表
        if found_tasks then
          tasks[rel_path] = file_tasks
        end
      end
    end
  end

  return tasks
end

-- 函数：更新dashboard.md文件
local function update_dashboard(tasks)
  -- 读取dashboard内容
  local file = io.open(dashboard_path:absolute(), "r")
  local dashboard_content = ""
  local in_tasks_section = false
  local header_found = false

  if file then
    for line in file:lines() do
      -- 保存frontmatter和非任务部分
      if not in_tasks_section then
        dashboard_content = dashboard_content .. line .. "\n"
      end

      -- 识别任务列表开始标记
      if line == "## 未完成任务" then
        in_tasks_section = true
        header_found = true
      end

      -- 识别任务列表结束标记
      if in_tasks_section and line == "## " then
        in_tasks_section = false
        dashboard_content = dashboard_content .. line .. "\n"
      end
    end
    file:close()
  end

  -- 如果没有找到任务列表标题，添加一个
  if not header_found then
    dashboard_content = dashboard_content .. "\n## 未完成任务\n"
  end

  -- 构建新的任务列表内容
  local tasks_content = ""
  local total_tasks = 0

  -- 按文件名排序
  local sorted_files = {}
  for file_path, _ in pairs(tasks) do
    table.insert(sorted_files, file_path)
  end
  table.sort(sorted_files)

  -- 生成任务列表内容
  for _, file_path in ipairs(sorted_files) do
    local file_tasks = tasks[file_path]
    if #file_tasks > 0 then
      tasks_content = tasks_content .. "\n### " .. file_path .. "\n\n"
      for _, task in ipairs(file_tasks) do
        tasks_content = tasks_content .. task.line .. "\n"
        total_tasks = total_tasks + 1
      end
    end
  end

  -- 添加任务总数统计
  if total_tasks > 0 then
    tasks_content = "\n> 共有 " .. total_tasks .. " 个未完成任务\n" .. tasks_content
  else
    tasks_content = "\n> 没有未完成任务\n"
  end

  -- 在dashboard中找到任务列表位置并插入新内容
  local new_content = ""
  local sections = vim.split(dashboard_content, "\n## ", true)

  if #sections > 1 then
    new_content = sections[1]
    for i = 2, #sections do
      local section = sections[i]
      if section:match("^未完成任务") then
        -- 替换任务部分
        new_content = new_content .. "\n## 未完成任务" .. tasks_content
      else
        -- 保留其他部分
        new_content = new_content .. "\n## " .. section
      end
    end
  else
    -- 如果没有section，直接添加任务部分
    new_content = dashboard_content .. "\n## 未完成任务" .. tasks_content .. "\n"
  end

  -- 写入更新后的内容到dashboard.md
  file = io.open(dashboard_path:absolute(), "w")
  if file then
    file:write(new_content)
    file:close()
    print("已更新 dashboard.md，共有 " .. total_tasks .. " 个未完成任务")
    return true
  else
    print("无法写入 dashboard.md")
    return false
  end
end

-- 主函数
local function collect_and_update_dashboard()
  print("开始收集未完成任务...")
  local tasks = collect_uncompleted_tasks()
  print("找到任务，正在更新 dashboard.md...")
  local success = update_dashboard(tasks)

  if success then
    -- 在当前buffer是dashboard.md的情况下重新加载
    local current_buf = vim.api.nvim_get_current_buf()
    local current_file = vim.api.nvim_buf_get_name(current_buf)

    if current_file:match("dashboard%.md$") then
      vim.cmd("edit!")
    end
  end
end

-- 导出函数，让init.lua可以调用
return {
  collect_and_update_dashboard = collect_and_update_dashboard,
}
