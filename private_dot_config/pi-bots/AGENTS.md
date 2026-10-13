# Pi-Bots AI 管理与操作铁律 (AI Agent Directives)

你当前正在 `~/.config/pi-bots/` 目录下操作。本项目遵循 **“一个共享底座 (`_base`) + 零拷贝派生子 Bot”** 架构。完整的架构图与参数说明请参阅同目录下的 `README.md`。

当你在此目录下执行创建、修改或维护子 Bot 任务时，**必须无条件遵守以下铁律**：

## 1. 严禁重复安装 NPM 依赖
- **绝对禁止**在任何子 Bot 目录下执行 `npm install`、`pi install` 或重新下载基础插件。
- 任何新建子 Bot 必须将 `npm` 目录软链接至 `../_base/npm` (`ln -sf ../_base/npm npm`)。
- **推荐做法**：直接调用 `./create-bot.sh <bot-name>` 脚本完成自动化初始化。

## 2. 凭证统一软链接指向 `_base`
- 子 Bot 的 `auth.json`、`models.json`、`antigravity-accounts.json`、`models-store.json` 必须全部软链接至 `../_base/`，严禁在子目录下创建独立的凭证副本。

## 3. 插件黑名单红线
- ❌ **严禁**给任何子 Bot 引入 `npm:pi-observational-memory`（避免与主 Agent 记忆冲突）。
- ❌ **严禁**给非协调类子 Bot 引入 `npm:pi-subagents`（避免无限嵌套递归派发）。

## 4. 记忆与会话严格局部化
- 严禁将子 Bot 的 `sessions/` 或专有记忆/状态目录软链接至 `_base/`。
- 会话和记忆必须留在该 Bot 自己的目录下，保证各角色间绝对隔离。

## 5. 人设与灵魂规范
- 每个子 Bot 的专属目录下必须包含其专有的 `AGENTS.md`，用于定义该角色的专业特质、思考风格、记忆读写习惯与行为边界。
