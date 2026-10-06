// @ts-nocheck
/**
 * Auto Rename Extension for Pi & Herdr
 *
 * 功能特性：
 * 1. 自动根据首条用户消息生成简短中文标题（4-10字）。
 * 2. 默认使用当前主模型（ctx.model）进行提炼，无需配置额外的外部模型路由。
 * 3. 异步后台生成，完全不阻塞主对话响应。
 * 4. 同步更新 Pi 会话名称（pi.setSessionName）及 Herdr 窗口与标签名字（herdr pane/tab rename）。
 * 5. 恢复会话时自动将已有名称同步至 Herdr 标签。
 * 6. 支持 /rename [新名字] 手动重命名或重新自动提炼。
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function updateHerdr(title: string): Promise<void> {
  const paneId = process.env.HERDR_PANE_ID;
  if (process.env.HERDR_ENV !== "1" || !paneId) return;

  try {
    // 1. 重命名当前 pane
    await execFileAsync("herdr", ["pane", "rename", paneId, title], { timeout: 3000 });

    // 2. 查询 pane 信息获取 tab_id
    const { stdout } = await execFileAsync("herdr", ["pane", "get", paneId], { timeout: 3000 });
    const data = JSON.parse(stdout);
    const tabId = data?.result?.pane?.tab_id;
    if (tabId) {
      // 3. 重命名当前 tab
      await execFileAsync("herdr", ["tab", "rename", tabId, title], { timeout: 3000 });
    }
  } catch {
    // 忽略 Herdr 通信异常
  }
}

function cleanTitle(raw: string): string {
  if (!raw || typeof raw !== "string") return "";
  let title = raw.trim();

  // 清除代码块标记
  title = title.replace(/^```[a-z]*\s*/i, "").replace(/\s*```$/i, "").trim();

  // 取首个非空行
  const lines = title.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  if (lines.length > 0) {
    title = lines[0];
  }

  // 清除 Markdown 标题和粗体
  title = title.replace(/^#+\s*/, "").replace(/^\*\*|\*\*$/g, "").replace(/^`+|`+$/g, "");

  // 清除开头的标签如 [需求] 或 【调研】
  title = title.replace(/^[\[【][^\]】]*[\]】]\s*/, "");

  // 清除常见前缀
  title = title.replace(/^(?:会话|对话|建议|任务)?(?:标题|名称|主题|Title|Summary)[:：]\s*/i, "");

  // 清除首尾引号及括号等符号
  title = title.replace(/^["'“”‘’《》「」【】\[\]()（）\s]+|["'“”‘’《》「」【】\[\]()（）\s]+$/g, "");

  // 清除末尾标点
  title = title.replace(/[。，！？,.!?；;…~～\s]+$/g, "");

  title = title.trim();

  // 限制长度在 12 个汉字以内
  if (title.length > 12) {
    title = title.slice(0, 12);
  }

  return title;
}

async function generateTitle(text: string, ctx: ExtensionContext): Promise<string | undefined> {
  const model = ctx.model;
  if (!model) return undefined;

  const systemPrompt =
    "你是一个会话标题提炼助手。根据用户的提问或任务，提炼一个简短、凝练的中文标题。\n" +
    "要求：\n" +
    "1. 必须使用中文（除Git、API、Bug等通用英文术语外）。\n" +
    "2. 长度控制在4到10个字之间。\n" +
    "3. 仅输出提炼后的标题本身，严禁输出任何标点符号（无书名号、无引号、无句号等）、解释、前缀或多余内容。";

  // 注意：TranscriptContext 只认 messages 里的 system 消息。直接调用 provider.streamSimple
  // 会静默丢弃 systemPrompt，模型就会把用户原话当对话继续回答。走 modelRegistry.streamSimple
  // 才会把 Context.systemPrompt 规范化成首条 system 消息，同时自动注入鉴权信息。
  const completionContext = {
    systemPrompt,
    messages: [{ role: "user", content: text.slice(0, 1500), timestamp: Date.now() }],
  };

  let response: any;
  try {
    // 优先尝试 reasoning: "off" 以极速返回
    response = await ctx.modelRegistry
      .streamSimple(model, completionContext as any, { reasoning: "off", maxRetries: 0 })
      .result();
  } catch {
    try {
      // 针对强制开启思考的模型，回退到当前 thinkingLevel 或默认参数
      const opts: any = { maxRetries: 0 };
      if (ctx.thinkingLevel && ctx.thinkingLevel !== "off") {
        opts.reasoning = ctx.thinkingLevel;
      }
      response = await ctx.modelRegistry.streamSimple(model, completionContext as any, opts).result();
    } catch {
      return undefined;
    }
  }

  if (!response || !response.content) return undefined;

  const raw = (Array.isArray(response.content) ? response.content : [])
    .filter((p: any) => p && p.type === "text" && typeof p.text === "string")
    .map((p: any) => p.text)
    .join("")
    .trim();

  const title = cleanTitle(raw);
  return title || undefined;
}

function extractText(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .flatMap((part) =>
      part && typeof part === "object" && part.type === "text" && typeof part.text === "string"
        ? [part.text]
        : [],
    )
    .join("\n");
}

function getRecentUserText(ctx: ExtensionContext): string | undefined {
  const branch = ctx.sessionManager?.getBranch?.() || [];
  const userTexts: string[] = [];
  for (let i = branch.length - 1; i >= 0 && userTexts.length < 3; i--) {
    const entry = branch[i];
    if (entry.type === "message" && entry.message.role === "user") {
      const text = extractText(entry.message.content);
      if (text.trim()) {
        userTexts.unshift(text.trim());
      }
    }
  }
  return userTexts.length > 0 ? userTexts.join("\n") : undefined;
}

export default function autoRenameExtension(pi: ExtensionAPI): void {
  let hasNamed = false;
  let autoNaming = false;

  // 会话启动或切换/恢复时同步 Herdr
  pi.on("session_start", async (_event, _ctx) => {
    autoNaming = false;
    const currentName = pi.getSessionName();
    if (currentName) {
      hasNamed = true;
      await updateHerdr(currentName);
    } else {
      hasNamed = false;
    }
  });

  // 当会话名称变动时（如通过 /name、/rename 或 API），自动同步 Herdr
  pi.on("session_info_changed", async () => {
    const name = pi.getSessionName();
    if (name) {
      hasNamed = true;
      await updateHerdr(name);
    }
  });

  // 在新会话的首条用户消息到达时后台自动重命名
  pi.on("before_agent_start", async (event, ctx) => {
    const currentName = pi.getSessionName();
    if (currentName) {
      hasNamed = true;
      return;
    }
    if (hasNamed || autoNaming) return;

    const prompt = event.prompt?.trim();
    if (!prompt) return;

    autoNaming = true;

    // 后台异步执行，不等待，完全不阻塞主交互
    (async () => {
      try {
        const title = await generateTitle(prompt, ctx);
        if (title) {
          pi.setSessionName(title);
          hasNamed = true;
          await updateHerdr(title);
          ctx.ui.notify?.(`会话已自动重命名为：${title}`, "info");
        }
      } catch {
        // 忽略错误
      } finally {
        autoNaming = false;
      }
    })();
  });

  // 注册手动 /rename 命令
  pi.registerCommand("rename", {
    description: "重命名当前会话及 Herdr 标签（支持传入自定义中文名称或由主模型自动提炼）",
    handler: async (args, ctx) => {
      let customTitle = args?.trim();
      if (customTitle) {
        customTitle = cleanTitle(customTitle);
        if (!customTitle) {
          ctx.ui.notify?.("提供的会话名称无效", "warning");
          return;
        }
        pi.setSessionName(customTitle);
        await updateHerdr(customTitle);
        ctx.ui.notify?.(`已重命名为：${customTitle}`, "info");
        return;
      }

      const promptText = getRecentUserText(ctx);
      if (!promptText) {
        ctx.ui.notify?.("未找到可用对话内容进行提炼", "warning");
        return;
      }

      ctx.ui.notify?.("正在使用主模型提炼会话名称...", "info");
      const title = await generateTitle(promptText, ctx);
      if (title) {
        pi.setSessionName(title);
        hasNamed = true;
        await updateHerdr(title);
        ctx.ui.notify?.(`已重命名为：${title}`, "info");
      } else {
        ctx.ui.notify?.("提炼会话名称失败", "warning");
      }
    },
  });
}
