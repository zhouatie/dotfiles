# Pi-Bots: 多角色子 Agent 架构与管理体系

`pi-bots` 是专为 Pi 设计的多角色子 Agent 托管体系。它通过 **“一个共享底座（`_base`）+ 零拷贝轻量派生”** 架构，实现了子 Bot 的秒级创建、依赖 100% 复用以及完全隔离的记忆与会话管理。

---

## 一、核心设计理念

1. **共享底座，零重复安装**：
   所有通用的生产力扩展（200+ npm 依赖包）统一由 `_base/npm` 维护一次。派生的子 Bot 通过软链接直接复用，创建新角色无需经历漫长的 `npm install`。
2. **凭据与模型全局同步**：
   各 Bot 的认证信息（`auth.json`、`models.json`）统一软链接至全局 `~/.config/pi/`，单点维护，永久同步。
3. **记忆与人格绝对隔离**：
   每个子 Bot 拥有独立的目录、独立的灵魂人设（`AGENTS.md`）和独立的会话记录（`sessions/`），各自演化，互不干扰。

---

## 二、目录树结构

```text
~/.config/pi-bots/
├── README.md                   # 📖【人类手册】架构图解、管理规范与使用说明
├── AGENTS.md                   # 🤖【AI 准则】约束大模型操作本目录的精简铁律
├── create-bot.sh               # 🛠️【脚手架】0.1 秒秒级创建新 Bot 脚本
│
├── _base/                      # 🧱【共享基础底座】
│   ├── npm/                    # ⚡ 共享插件依赖库（已预装所有基础工具）
│   ├── settings.base.json      # ⚡ 共享标准配置模版
│   ├── auth.json -> ../../pi/auth.json
│   ├── models.json -> ../../pi/models.json
│   ├── antigravity-accounts.json -> ../../pi/...
│   └── models-store.json -> ../../pi/...
│
└── raven/                      # 🏗️【Raven 实例：架构设计与模块重构】
    ├── npm -> ../_base/npm     # ⚡ 零拷贝复用基础依赖
    ├── auth.json -> ../_base/auth.json
    ├── models.json -> ../_base/models.json
    ├── settings.json           # 专属配置
    ├── AGENTS.md               # Raven 专属工程师灵魂与设计准则
    ├── skills/                 # 专属技能库
    └── sessions/               # 专属会话存储
```

---

## 三、快速创建新 Bot

使用内置的脚手架脚本 `create-bot.sh`，创建新 Bot 仅需 **0.1 秒**：

```bash
~/.config/pi-bots/create-bot.sh <bot-name> [描述]
```

### 示例：
```bash
~/.config/pi-bots/create-bot.sh grok "追求极简实用主义的轻量助手"
```

该脚本会自动执行：
1. 创建 `~/.config/pi-bots/<bot-name>/` 目录；
2. 建立 `npm`、`auth.json`、`models.json` 到 `../_base/` 的软链接；
3. 从 `_base/settings.base.json` 复制生成 `settings.json`；
4. 生成 `AGENTS.md` 模板；
5. 在 `~/.zshrc` 中注册专属终端快捷别名 `alias pi-<bot-name>=...`。

---

## 四、插件选用分类矩阵

为了保持子 Bot 的精简高效，插件分为以下四类：

| 分类 | 包含插件 | 说明 |
| :--- | :--- | :--- |
| **基础底座（已预装在 base）** | `tool-repair`, `edit-guard`, `web-access`, `fff`, `antigravity`, `mcp-adapter` | 自动参数纠错、代码防毁、联网查资料、极速检索。所有 Bot 默认享有。 |
| **交互增强（已预装在 base）** | `open-tui`, `side-chat`, `extmgr`, `omp-titanium` 主题 | 提升单聊结对编程时的终端体验。 |
| **专精选配（按需装入各 Bot）** | `ponytail` (极简架构), `visualize-code-changes` (流程图), `playwright` (端到端测试) | 仅当 Bot 明确需要对应专长时，写入该 Bot 的 `settings.json`。 |
| **❌ 绝对禁选黑名单** | `pi-observational-memory`, `pi-subagents` | 严禁装入子 Bot，防止双重记忆打架与多层递归调度失控。 |

---

## 五、使用与调用方式

1. **终端交互单聊**：
   ```bash
   pi-raven        # 启动 Raven
   pi-qa           # 启动 QA
   ```
2. **命令行单次任务**：
   ```bash
   PI_CODING_AGENT_DIR=~/.config/pi-bots/raven pi -p "分析当前模块架构并提出重构建议"
   ```
