// @ts-nocheck
/**
 * Orchestrator Mode Extension for Pi
 *
 * Features:
 * - Tab to toggle between Normal and Orchestrator modes when editor is empty
 * - Shortcut: Ctrl+Alt+O to toggle mode anytime
 * - Shift+Tab to toggle mode anytime
 * - Slash command: /mode or /orchestrator to toggle mode
 * - In Orchestrator mode:
 *   1. Direct file edits (edit/write) are blocked.
 *   2. The agent plans, breaks down tasks, and delegates to subagents (scout, worker, reviewer).
 *   3. All subagents run asynchronously (async: true) in background without blocking conversation.
 *   4. subagent_wait is blocked to prevent freezing user interaction.
 * - Minimal status indicator: only shows subtle status in footer when orchestrator mode is active.
 */

import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { matchesKey } from "@earendil-works/pi-tui";

type AgentMode = "normal" | "orchestrator";

export default function (pi: ExtensionAPI) {
  let currentMode: AgentMode = "normal";

  function updateModeUI(ctx: any) {
    if (!ctx?.hasUI) return;
    // 极简指示：指挥官模式下在底栏显示简洁标识，普通模式完全清空不占位置
    ctx.ui.setStatus("mode", currentMode === "orchestrator" ? "🧭 orchestrator" : undefined);
  }

  // 1. 底层终端输入监听：捕获空输入框中的 Tab 键与任何时候的 Shift+Tab
  pi.on("session_start", (_event, ctx) => {
    if (ctx.hasUI && typeof ctx.ui?.onTerminalInput === "function") {
      ctx.ui.onTerminalInput((data: string) => {
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
          currentMode = currentMode === "normal" ? "orchestrator" : "normal";
          updateModeUI(ctx);
          return { consume: true };
        }

        // Tab：仅在输入框为空时切换；有文字输入时放行给补全系统
        if (isTab) {
          const currentText = (ctx.ui.getEditorText?.() ?? "").trim();
          if (currentText === "") {
            currentMode = currentMode === "normal" ? "orchestrator" : "normal";
            updateModeUI(ctx);
            return { consume: true };
          }
        }

        return undefined;
      });
    }

    updateModeUI(ctx);
  });

  // 2. 动态注入模式提示词：指挥官模式下强制规划与委派
  pi.on("before_agent_start", async (event, _ctx) => {
    if (currentMode === "orchestrator") {
      const orchestratorPrompt = [
        "## [ACTIVE MODE: ORCHESTRATOR / DISPATCHER]",
        "- You are currently acting in ORCHESTRATOR mode.",
        "- DO NOT perform file edits or write code yourself (edit and write tools are disabled).",
        "- Your role: High-level architectural analysis, task decomposition, and delegation to child subagents via `subagent`.",
        "- Builtin subagents to use:",
        "  * `worker`: for implementing code changes, writing files, and running builds/tests",
        "  * `scout`: for inspecting codebase structure, entry points, and dependencies (read-only)",
        "  * `reviewer`: for reviewing code diffs, edge cases, and correctness (read-only)",
        "  * `researcher`: for searching docs and external libraries",
        "- NON-BLOCKING REQUIREMENT: All subagent tasks must run in the background (async: true). NEVER call subagent_wait or wait synchronously for tasks to complete.",
        "- Briefly outline your plan, call `subagent` with async: true, inform the user with task IDs / details, and finish your turn immediately so the user can continue talking without being blocked.",
      ].join("\n");

      return {
        systemPrompt: event.systemPrompt + "\n\n" + orchestratorPrompt,
      };
    }
  });

  // 3. 工具层物理拦截：禁止修改代码，强制异步后台，禁止卡住对话
  pi.on("tool_call", async (event) => {
    if (currentMode !== "orchestrator") return;

    // (A) 拦截直接修改代码的工具
    if (event.toolName === "edit" || event.toolName === "write") {
      return {
        block: true,
        reason: "【指挥官模式】禁止主 Agent 直接修改或写入代码。请将修改任务通过 subagent 工具指派给 worker 子代理执行。",
      };
    }

    // (B) 强制 subagent 以异步后台方式运行（async: true）
    if (event.toolName === "subagent") {
      if (event.input && typeof event.input === "object") {
        event.input.async = true;
      }
    }

    // (C) 拦截阻塞等待工具，防止卡死对话
    if (event.toolName === "subagent_wait") {
      return {
        block: true,
        reason: "【指挥官模式】禁止同步阻塞等待。请直接向用户汇报已派发的后台任务并结束当前轮次，保持主对话随时可用。",
      };
    }
  });

  // 4. 备用 Slash 命令
  pi.registerCommand("mode", {
    description: "切换工作模式 (Normal / Orchestrator)",
    handler: async (_args, ctx) => {
      currentMode = currentMode === "normal" ? "orchestrator" : "normal";
      updateModeUI(ctx);
    },
  });

  pi.registerCommand("orchestrator", {
    description: "切换指挥官模式",
    handler: async (_args, ctx) => {
      currentMode = currentMode === "normal" ? "orchestrator" : "normal";
      updateModeUI(ctx);
    },
  });

  // 5. 额外快捷键支持 (Ctrl+Alt+O)
  pi.registerShortcut("ctrl+alt+o", {
    description: "切换工作模式 (Normal / Orchestrator)",
    handler: async (ctx) => {
      currentMode = currentMode === "normal" ? "orchestrator" : "normal";
      updateModeUI(ctx);
    },
  });
}
