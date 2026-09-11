// @ts-nocheck
/**
 * Master Mode Extension for Pi
 *
 * Features:
 * - Fixed Top Indicator: Anchored right above the input box border (Line 0 of editor).
 *   Intercepts ctx.ui.setEditorComponent so it works seamlessly even when pi-open-tui
 *   or other custom editor packages are installed.
 * - Persistent Mode State: Saved to ~/.config/pi/.master-mode-state.json so mode survives restarts.
 * - Tab to toggle between Normal and Master modes when editor is empty.
 * - Shortcut: Shift+Tab to toggle mode anytime.
 * - Shortcut: Ctrl+Alt+M (or Ctrl+Alt+O) to toggle mode anytime.
 * - Slash command:
 *   - /mode [master|normal] with argument autocomplete
 *   - /master (or /orchestrator alias)
 * - In Master mode:
 *   1. Direct file edits (edit/write) are blocked for the main dispatcher agent.
 *   2. The agent plans, breaks down tasks, and delegates to subagents (scout, worker, reviewer).
 *   3. All subagents run asynchronously (async: true) in background without blocking conversation.
 *   4. subagent_wait is blocked to prevent freezing user interaction.
 *   5. Single Writer Rule: Read subagents run in parallel freely, but at most ONE writer (worker) is allowed in the workspace at any time to avoid write conflicts.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { homedir } from "node:os";
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey, visibleWidth, type AutocompleteItem } from "@earendil-works/pi-tui";

type AgentMode = "normal" | "master";

const STATE_FILE = path.join(homedir(), ".config", "pi", ".master-mode-state.json");

function loadPersistedMode(): AgentMode {
  try {
    if (fs.existsSync(STATE_FILE)) {
      const data = JSON.parse(fs.readFileSync(STATE_FILE, "utf-8"));
      if (data && (data.defaultMode === "master" || data.defaultMode === "normal")) {
        return data.defaultMode;
      }
    }
  } catch (e) {
    // ignore
  }
  return "master"; // 默认优先保持 Master 模式
}

function savePersistedMode(mode: AgentMode) {
  try {
    const data = { defaultMode: mode, updatedAt: new Date().toISOString() };
    fs.writeFileSync(STATE_FILE, JSON.stringify(data, null, 2), "utf-8");
  } catch (e) {
    // ignore
  }
}

export default function (pi: ExtensionAPI) {
  let currentMode: AgentMode = loadPersistedMode();
  let activeTui: any = undefined;
  let activeTheme: any = undefined;

  function isEditorEmpty(text?: string | null): boolean {
    if (!text) return true;
    // 宽松空值判定：排除掉首尾空白、换行、零宽空格 (Zero-width)、BOM 以及不可见控制字符
    const cleaned = text.replace(/[\u200B-\u200D\uFEFF\u00A0\0]/g, "").trim();
    return cleaned === "";
  }

  function updateModeUI(ctx?: any) {
    savePersistedMode(currentMode);

    // 清理旧残留的浮动 Widget 与底栏状态，防止干扰
    if (ctx?.ui && typeof ctx.ui.setWidget === "function") {
      ctx.ui.setWidget("master-mode", undefined);
      ctx.ui.setWidget("orchestrator-mode", undefined);
    }
    if (ctx?.ui && typeof ctx.ui.setStatus === "function") {
      ctx.ui.setStatus("mode", undefined);
    }

    // 触发 TUI 重新渲染以即时刷新固定在输入框上方的模式标识（不调用 notify 避免污染会话记录）
    activeTui?.requestRender?.();
  }

  // 1. 底层拦截并包装输入框组件，保证指示条永远死死固定在输入框顶边框正上方（Line 0）
  pi.on("session_start", (_event, ctx) => {
    currentMode = loadPersistedMode();

    if (ctx.hasUI && ctx.ui) {
      const ui = ctx.ui;
      activeTheme = ui.theme;

      // 1. Wrap function
      function wrapEditor(editorInstance: any) {
        if (!editorInstance || editorInstance.__masterModeWrapped) {
          return editorInstance;
        }
        editorInstance.__masterModeWrapped = true;

        const originalRender = editorInstance.render.bind(editorInstance);
        editorInstance.render = function (width: number): string[] {
          const lines = originalRender(width);
          if (!lines || lines.length === 0) return lines;

          if (currentMode !== "master") {
            return lines;
          }

          const theme = activeTheme ?? ui.theme;
          let badge = " Master";

          if (typeof theme?.fg === "function") badge = theme.fg("accent", badge);
          if (typeof theme?.bold === "function") badge = theme.bold(badge);

          return [badge, ...lines];
        };

        const originalHandleMouse = editorInstance.handleMouse ? editorInstance.handleMouse.bind(editorInstance) : undefined;
        if (originalHandleMouse) {
          editorInstance.handleMouse = function (event: any) {
            if (currentMode !== "master") {
              return originalHandleMouse(event);
            }
            if (event.y === 0) {
              return { handled: true, focus: true };
            }
            return originalHandleMouse({ ...event, y: Math.max(0, event.y - 1) });
          };
        }

        return editorInstance;
      }

      // 2. Intercept ctx.ui.setEditorComponent so ANY extension (like pi-open-tui) calling it is wrapped!
      if (typeof ui.setEditorComponent === "function") {
        const originalSetEditor = ui.setEditorComponent.bind(ui);

        ui.setEditorComponent = function (factory: any) {
          if (!factory) {
            return originalSetEditor(undefined);
          }
          return originalSetEditor((tui: any, theme: any, keybindings: any) => {
            activeTui = tui;
            activeTheme = theme;
            const created = factory(tui, theme, keybindings);
            return wrapEditor(created);
          });
        };

        // Immediately wrap current factory or initialize default CustomEditor
        const currentFactory = ui.getEditorComponent?.();
        if (currentFactory) {
          ui.setEditorComponent(currentFactory);
        } else {
          ui.setEditorComponent((tui: any, theme: any, keybindings: any) => {
            return new CustomEditor(tui, theme, keybindings);
          });
        }
      }

      // 终端按键监听
      if (typeof ui.onTerminalInput === "function") {
        ui.onTerminalInput((data: string) => {
          const isTab =
            matchesKey(data, "tab") ||
            data === "\t" ||
            data === "\x09" ||
            data === "\x1b[9;1u" ||
            data === "\x1b[9u";

          const isShiftTab =
            matchesKey(data, "shift+tab") ||
            data === "\x1b[Z" ||
            data === "\x1b[9;2u" ||
            data === "\x1b[1;2Z";

          // Shift+Tab：直接切换
          if (isShiftTab) {
            currentMode = currentMode === "normal" ? "master" : "normal";
            updateModeUI(ctx);
            return { consume: true };
          }

          // Tab：仅在输入框为空时切换；有文字输入时放行给补全系统
          if (isTab) {
            const currentText = ui.getEditorText?.() ?? "";
            if (isEditorEmpty(currentText)) {
              currentMode = currentMode === "normal" ? "master" : "normal";
              updateModeUI(ctx);
              return { consume: true };
            }
          }

          return undefined;
        });
      }
    }

    updateModeUI(ctx);
  });

  pi.on("session_shutdown", () => {
    activeTui = undefined;
    activeTheme = undefined;
  });

  // 2. 动态注入模式提示词：Master 模式下强制规划与委派
  pi.on("before_agent_start", async (event, _ctx) => {
    if (currentMode === "master") {
      const masterPrompt = [
        "## [ACTIVE MODE: MASTER / DISPATCHER]",
        "- You are currently acting in MASTER mode.",
        "- DO NOT perform file edits or write code yourself (edit and write tools are disabled).",
        "- Your role: High-level architectural analysis, task decomposition, and delegation to child subagents via `subagent`.",
        "- Builtin subagents to use:",
        "  * `worker`: for implementing code changes, writing files, and running builds/tests",
        "  * `scout`: for inspecting codebase structure, entry points, and dependencies (read-only)",
        "  * `reviewer`: for reviewing code diffs, edge cases, and correctness (read-only)",
        "  * `researcher`: for searching docs and external libraries",
        "- CONCURRENCY SAFETY & SINGLE WRITER RULE (CRITICAL):",
        "  * NEVER launch multiple `worker` subagents in parallel within the same workspace; concurrent writes will overwrite files or cause edit conflicts.",
        "  * Read/Write separation: Read-only subagents (`scout`, `reviewer`, `researcher`) can be freely run in parallel, but at most ONE `worker` writer may run at any time in the same workspace.",
        "  * Multi-task handling: When multiple modification tasks exist, they MUST be executed sequentially (dispatch next worker only after previous finishes), or sequenced with `await runs.run(...)` inside `workflowScript`, or isolated with `worktree: true`.",
        "- NON-BLOCKING REQUIREMENT: All subagent tasks must run in the background (async: true). NEVER call subagent_wait or wait synchronously for tasks to complete.",
        "- Briefly outline your plan, call `subagent` with async: true, inform the user with task IDs / details, and finish your turn immediately so the user can continue talking without being blocked.",
      ].join("\n");

      return {
        systemPrompt: event.systemPrompt + "\n\n" + masterPrompt,
      };
    } else {
      const normalPrompt = [
        "## [ACTIVE MODE: NORMAL / DIRECT EXECUTION]",
        "- You are currently in NORMAL mode.",
        "- Even if previous turns in this conversation were in Master/Dispatcher mode, Master mode is now DEACTIVATED.",
        "- You have full access to all tools including `edit`, `write`, and `bash`.",
        "- You SHOULD directly write code, edit files, and answer questions yourself instead of delegating to subagents, unless the user explicitly requests a subagent.",
      ].join("\n");

      return {
        systemPrompt: event.systemPrompt + "\n\n" + normalPrompt,
      };
    }
  });

  // 3. 工具层物理拦截：禁止修改代码，强制异步后台，禁止卡住对话
  pi.on("tool_call", async (event) => {
    if (currentMode !== "master") return;

    if (event.toolName === "edit" || event.toolName === "write") {
      return {
        block: true,
        reason: "【Master 模式】禁止主 Agent 直接修改或写入代码。请将修改任务通过 subagent 工具指派给 worker 子代理执行。",
      };
    }

    if (event.toolName === "subagent") {
      if (event.input && typeof event.input === "object") {
        event.input.async = true;
      }
    }

    if (event.toolName === "subagent_wait") {
      return {
        block: true,
        reason: "【Master 模式】禁止同步阻塞等待。请直接向用户汇报已派发的后台任务并结束当前轮次，保持主对话随时可用。",
      };
    }
  });

  // 4. Slash 命令支持
  pi.registerCommand("mode", {
    description: "切换工作模式 (normal / master)",
    getArgumentCompletions: (prefix: string): AutocompleteItem[] | null => {
      const options: AutocompleteItem[] = [
        { value: "master", label: "master (Master 模式)" },
        { value: "normal", label: "normal (普通模式)" },
      ];
      const filtered = options.filter((o) => o.value.startsWith(prefix.trim().toLowerCase()));
      return filtered.length > 0 ? filtered : null;
    },
    handler: async (args, ctx) => {
      const target = args?.trim().toLowerCase();
      if (target === "master" || target === "orchestrator") {
        currentMode = "master";
      } else if (target === "normal") {
        currentMode = "normal";
      } else {
        currentMode = currentMode === "normal" ? "master" : "normal";
      }
      updateModeUI(ctx);
    },
  });

  pi.registerCommand("master", {
    description: "切换到 Master 模式",
    handler: async (_args, ctx) => {
      currentMode = currentMode === "normal" ? "master" : "normal";
      updateModeUI(ctx);
    },
  });

  pi.registerCommand("orchestrator", {
    description: "切换到 Master 模式 (别名)",
    handler: async (_args, ctx) => {
      currentMode = currentMode === "normal" ? "master" : "normal";
      updateModeUI(ctx);
    },
  });

  // 5. 快捷键支持 (Ctrl+Alt+M 及别名 Ctrl+Alt+O)
  pi.registerShortcut("ctrl+alt+m", {
    description: "切换工作模式 (Normal / Master)",
    handler: async (ctx) => {
      currentMode = currentMode === "normal" ? "master" : "normal";
      updateModeUI(ctx);
    },
  });

  pi.registerShortcut("ctrl+alt+o", {
    description: "切换工作模式 (Normal / Master) - 兼容快捷键",
    handler: async (ctx) => {
      currentMode = currentMode === "normal" ? "master" : "normal";
      updateModeUI(ctx);
    },
  });
}
