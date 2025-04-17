-- 解决在 lazyvim.json lazy-lock.json 两个文件中移动 报错的 bug

return {
  "RRethy/vim-illuminate",
  event = "LazyFile",
  -- 禁用自带的 illuminate 配置，完全用我们的覆盖它
  enabled = true, -- 启用插件
  keys = {
    { "]]", desc = "Next Reference" },
    { "[[", desc = "Prev Reference" },
  },
  opts = {
    -- 只使用 treesitter 和 regex 方式高亮，不使用 LSP
    providers = {
      "treesitter",
      "regex",
    },
    -- 延迟触发高亮，减少频繁提示
    delay = 200,
    large_file_cutoff = 2000,
    under_cursor = true,
    min_count_to_highlight = 2,
    -- 添加不需要高亮的文件类型
    filetypes_denylist = {
      "help",
      "NvimTree",
      "TelescopePrompt",
      "alpha",
      "lazy",
      "mason",
      "notify",
      "lspinfo",
      "checkhealth",
      "qf",
    },
  },
  -- 替换 LazyVim 默认配置，而不是合并
  config = function(_, opts)
    -- 根据不同文件类型设置不同的模式
    local illuminate = require("illuminate")

    -- 添加此行禁用 illuminate 插件使用 LSP 请求
    illuminate.configure(opts)

    -- 关闭 LSP documentHighlight 请求
    -- 这是 illuminate 之外的，通过全局设置来禁用 LSP documentHighlight 功能
    local old_handler = vim.lsp.handlers["textDocument/documentHighlight"]
    vim.lsp.handlers["textDocument/documentHighlight"] = function(...)
      -- 完全禁用该功能，不做任何处理
      return
    end

    -- 隐藏 "method textDocument/documentHighlight is not supported" 的错误提示
    local old_publish_diagnostics = vim.lsp.handlers["textDocument/publishDiagnostics"]
    vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
      if result and result.diagnostics then
        local idx = 1
        while idx <= #result.diagnostics do
          local diagnostic = result.diagnostics[idx]
          -- 从结果中移除这类错误信息
          if diagnostic.message and diagnostic.message:match("textDocument/documentHighlight") then
            table.remove(result.diagnostics, idx)
          else
            idx = idx + 1
          end
        end
      end
      -- 处理其他诊断信息
      return old_publish_diagnostics(err, result, ctx, config)
    end
  end,
}
