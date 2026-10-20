#!/usr/bin/env node
/**
 * pi-mode — 切换 pi 的运行模式（work / home）
 *
 * 用法:
 *   node pi-mode.mjs work     切换到公司模式
 *   node pi-mode.mjs home     切换到家里模式
 *   node pi-mode.mjs          查看当前模式
 *
 * 行为:
 *   1. 读取 ~/.config/pi/profiles/pi-subagents/<mode>.json
 *   2. 将 profile.main 写入 settings.json 的 defaultProvider/defaultModel/defaultThinkingLevel
 *   3. 将 profile.subagents 合并进 settings.json（agentOverrides 整体替换，
 *      其余 subagents 键如 modelScope/watchdog 保留——与 pi-subagents 官方
 *      applySubagentProfile 逻辑一致）
 *
 * profile 文件同时兼容 pi-subagents 官方的 /subagents-load-profile <mode> 命令。
 */
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";

const AGENT_DIR =
  process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
const SETTINGS_PATH = path.join(AGENT_DIR, "settings.json");
const PROFILES_DIR = path.join(AGENT_DIR, "profiles", "pi-subagents");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf-8"));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf-8");
}

function fail(message) {
  console.error(`pi-mode: ${message}`);
  process.exit(1);
}

const mode = process.argv[2];

if (!mode) {
  const settings = readJson(SETTINGS_PATH);
  console.log(`当前主模型: ${settings.defaultProvider}/${settings.defaultModel}`);
  const profiles = fs
    .readdirSync(PROFILES_DIR)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.slice(0, -5));
  console.log(`可用模式: ${profiles.join(", ")}`);
  process.exit(0);
}

const profilePath = path.join(PROFILES_DIR, `${mode}.json`);
if (!fs.existsSync(profilePath)) {
  fail(`找不到 profile: ${profilePath}`);
}

const profile = readJson(profilePath);

// 防止误用未填写的模板
const raw = fs.readFileSync(profilePath, "utf-8");
if (raw.includes("TODO-")) {
  fail(`profile '${mode}' 里还有 TODO 占位符，请先编辑 ${profilePath} 填入家里实际可用的 provider/model`);
}

const settings = readJson(SETTINGS_PATH);

// 1. 主模型
if (profile.main) {
  if (profile.main.provider) settings.defaultProvider = profile.main.provider;
  if (profile.main.model) settings.defaultModel = profile.main.model;
  if (profile.main.thinking) settings.defaultThinkingLevel = profile.main.thinking;
}

// 2. Ctrl+P 模型循环列表（可选）
if (Array.isArray(profile.enabledModels) && profile.enabledModels.length > 0) {
  settings.enabledModels = profile.enabledModels;
}

// 3. subagents（复刻 pi-subagents applySubagentProfile 的合并语义）
if (profile.subagents) {
  const existing =
    settings.subagents &&
    typeof settings.subagents === "object" &&
    !Array.isArray(settings.subagents)
      ? settings.subagents
      : {};
  settings.subagents = {
    ...existing,
    ...profile.subagents,
    agentOverrides: profile.subagents.agentOverrides,
  };
}

writeJson(SETTINGS_PATH, settings);

console.log(`pi-mode: 已切换到 '${mode}'`);
if (profile.main) {
  console.log(`  主模型: ${settings.defaultProvider}/${settings.defaultModel} (${settings.defaultThinkingLevel ?? "default thinking"})`);
}
const roles = Object.keys(profile.subagents?.agentOverrides ?? {});
console.log(`  subagent 角色: ${roles.join(", ")}`);
console.log(`  对新启动的 pi 会话生效；已运行会话中新启动的 subagent 也会立即使用新映射，主模型需 /model 手动切换。`);
