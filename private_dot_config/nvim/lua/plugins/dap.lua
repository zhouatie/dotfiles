local js_based_languages = {
  "typescript",
  "javascript",
  "typescriptreact",
  "javascriptreact",
  "vue",
}

local react_native_languages = {
  "typescript",
  "javascript",
  "typescriptreact",
  "javascriptreact",
}

return {
  {
    "mfussenegger/nvim-dap",
    ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
    dependencies = {
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")

      require("nvim-dap-virtual-text").setup({
        clear_on_continue = true,
      })

      -- 设置更美观的调试图标
      vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError", linehl = "", numhl = "" })
      vim.fn.sign_define(
        "DapBreakpointCondition",
        { text = "◆", texthl = "DiagnosticSignWarn", linehl = "", numhl = "" }
      )
      vim.fn.sign_define("DapLogPoint", { text = "◉", texthl = "DiagnosticSignInfo", linehl = "", numhl = "" })
      vim.fn.sign_define(
        "DapStopped",
        { text = "➤", texthl = "DiagnosticSignHint", linehl = "DapStoppedLine", numhl = "" }
      )
      vim.fn.sign_define(
        "DapBreakpointRejected",
        { text = "✖", texthl = "DiagnosticSignError", linehl = "", numhl = "" }
      )

      -- 添加保存所有缓冲区的预启动钩子，解决"修改后的缓冲区"错误
      -- dap.listeners.before.launch.saveAll = function()
      --   vim.cmd("wa") -- 保存所有修改过的缓冲区
      -- end

      -- 共用同一个js-debug-adapter作为调试适配器
      local js_debug_adapter = {
        type = "server",
        host = "localhost",
        port = "${port}",
        executable = {
          command = vim.fn.expand("~/.local/share/nvim/mason/bin/js-debug-adapter"),
          args = { "${port}" },
        },
      }

      -- Node.js调试适配器
      dap.adapters["pwa-node"] = js_debug_adapter

      -- Chrome浏览器调试适配器
      dap.adapters["pwa-chrome"] = js_debug_adapter

      dap.adapters.chrome = {
        type = "executable",
        command = "node",
        args = { os.getenv("HOME") .. "/dap-debugger/vscode-chrome-debug/out/src/chromeDebug.js" },
      }

      -- node 支持
      -- 为支持的JavaScript相关语言创建通用配置
      for _, language in ipairs(js_based_languages) do
        dap.configurations[language] = {
          -- 调试当前文件
          {
            type = "pwa-node",
            request = "launch",
            name = "调试当前文件",
            program = "${file}",
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            runtimeExecutable = "node",
            -- TypeScript 需要 ts-node
            runtimeArgs = (function()
              if language:match("typescript") then
                return {
                  "--nolazy",
                  "-r",
                  "ts-node/register",
                }
              else
                return {}
              end
            end)(),
            outFiles = { "${workspaceFolder}/{dist,build,public}/**/*.js" },
            resolveSourceMapLocations = {
              "${workspaceFolder}/{dist,build,public}/**/*.js",
              "${workspaceFolder}/**/*.{ts,tsx,js,jsx}",
              "!**/node_modules/**",
            },
            skipFiles = { "<node_internals>/**" },
            console = "integratedTerminal",
          },
          {
            type = "pwa-node",
            request = "launch",
            name = "运行 npm dev",
            runtimeExecutable = "npm",
            runtimeArgs = { "dev" },
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            outFiles = { "${workspaceFolder}/{public, dist,build,out}/**/*.js" },
            resolveSourceMapLocations = {
              "${workspaceFolder}/{dist,build,out, public}/**/*.js",
              "${workspaceFolder}/**/*.{ts,tsx,js,jsx}",
              "!**/node_modules/**",
            },
            skipFiles = { "<node_internals>/**" },
            console = "integratedTerminal",
          },
          -- 附加到已运行的进程
          {
            type = "pwa-node",
            request = "attach",
            name = "附加到进程",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
            sourceMaps = true,
            outFiles = { "${workspaceFolder}/{dist,build,out,public}/**/*.js" },
            resolveSourceMapLocations = {
              "${workspaceFolder}/{dist,build,out,public}/**/*.js",
              "${workspaceFolder}/**/*.{ts,tsx,js,jsx}",
              "!**/node_modules/**",
            },
            skipFiles = { "<node_internals>/**" },
          },
        }
      end

      -- chrome 支持
      local chrome_debug_config = {
        {
          type = "pwa-chrome",
          request = "launch",
          name = "启动Chrome（launch）",
          url = "about:blank", -- 启动时打开空白页，然后手动输入URL
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          -- userDataDir = false,
          userDataDir = function()
            return "/Users/zhoushitie/Desktop/work/.chrome-debug-userData"
          end,
          runtimeExecutable = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
          -- runtimeArgs = { "--incognito" }, -- 启动无痕模式
          sourceMapPathOverrides = {
            -- 适用于大多数构建工具
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
            ["webpack:///node_modules/*"] = "${webRoot}/node_modules/*",
            ["*://engine/*"] = "${workspaceFolder}/engine/*",
            ["*://game/*"] = "${workspaceFolder}/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
        -- 连接到已运行的 Chrome 实例 (attach 模式)
        {
          type = "pwa-chrome",
          request = "attach",
          name = "连接到已运行的 Chrome",
          port = 9222,
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
            ["webpack:///node_modules/*"] = "${webRoot}/node_modules/*",
            ["*://engine/*"] = "${workspaceFolder}/engine/*",
            ["*://game/*"] = "${workspaceFolder}/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
      }

      -- 为所有支持前端调试的语言提供同样的 Chrome 配置
      for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact", "vue" }) do
        dap.configurations[lang] = vim.list_extend(dap.configurations[lang] or {}, chrome_debug_config)
      end

      -- React Native 调试配置
      local react_native_debug_config = {
        -- 连接到远程 iPhone 设备（推荐用于实际设备）
        {
          type = "pwa-chrome",
          request = "attach",
          name = "调试实体 iPhone 设备",
          url = "http://localhost:8081/debugger-ui/",
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
        -- 启动 Metro Bundler
        {
          type = "pwa-node",
          request = "launch",
          name = "启动 Metro Bundler",
          runtimeExecutable = "npm",
          runtimeArgs = { "start" },
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
          skipFiles = { "<node_internals>/**" },
        },
        -- 调试 iOS 模拟器
        {
          type = "pwa-chrome",
          request = "attach",
          name = "调试 iOS 模拟器",
          url = "http://localhost:8081/debugger-ui/",
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
        -- 调试 Android 模拟器
        {
          type = "pwa-chrome",
          request = "attach",
          name = "调试 Android 模拟器",
          url = "http://localhost:8081/debugger-ui/",
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["metro:///./*"] = "${webRoot}/*",
            ["metro:///src/*"] = "${webRoot}/src/*",
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
            ["webpack:///./src/*"] = "${webRoot}/src/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
        -- 调试实体 Android 设备
        {
          type = "pwa-chrome",
          request = "attach",
          name = "调试实体 Android 设备",
          url = "http://localhost:8081/debugger-ui/",
          webRoot = "${workspaceFolder}",
          sourceMaps = true,
          sourceMapPathOverrides = {
            ["metro:///./*"] = "${webRoot}/*",
            ["metro:///src/*"] = "${webRoot}/src/*",
            ["webpack:///./*"] = "${webRoot}/*",
            ["webpack:///src/*"] = "${webRoot}/src/*",
            ["webpack:///./src/*"] = "${webRoot}/src/*",
          },
          skipFiles = { "<node_internals>/**" },
        },
        -- 附加到运行中的应用（通用）
        {
          type = "pwa-node",
          request = "attach",
          name = "附加到运行中的应用",
          processId = require("dap.utils").pick_process,
          cwd = "${workspaceFolder}",
          skipFiles = { "<node_internals>/**" },
        },
      }

      -- 为 JavaScript 和 TypeScript 相关语言添加 React Native 调试配置
      for _, lang in ipairs(react_native_languages) do
        dap.configurations[lang] = vim.list_extend(dap.configurations[lang] or {}, react_native_debug_config)
      end
    end,
  },

  {
    "miroshQa/debugmaster.nvim",
    config = function()
      local dm = require("debugmaster")
      -- make sure you don't have any other keymaps that starts with "<leader>d" to avoid delay
      vim.keymap.set({ "n", "v" }, "<leader>d", dm.mode.toggle, { nowait = true })
      vim.keymap.set("t", "<C-/>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
      -- 设置 dCursor 高亮并确保不被 colorscheme 覆盖
      vim.api.nvim_set_hl(0, "dCursor", { bg = "#FF2C2C" })

      -- 创建自动命令组，确保高亮在 colorscheme 变更后仍然生效
      local augroup = vim.api.nvim_create_augroup("DapHighlightFix", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = function()
          vim.api.nvim_set_hl(0, "dCursor", { bg = "#FF2C2C" })
        end,
        desc = "保持 dCursor 高亮不被 colorscheme 覆盖",
      })
      dm.plugins.ui_auto_toggle.enabled = false
    end,
  },
}
