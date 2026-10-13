#!/usr/bin/env bash
set -e

# ==============================================================================
# Pi-Bots 快速脚手架：0 秒复用基础依赖，瞬间创建新子 Bot
# 用法: ./create-bot.sh <bot-name> [description]
# 示例: ./create-bot.sh grok "极简幽默的轻量代码助手"
# ==============================================================================

BOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$BOTS_DIR/_base"

if [ -z "$1" ]; then
  echo "❌ 错误: 请指定 Bot 名称！"
  echo "用法: ./create-bot.sh <bot-name> [description]"
  exit 1
fi

BOT_NAME="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
BOT_DESC="${2:-专属专精 Agent ($BOT_NAME)}"

# 校验名称合法性
if ! [[ "$BOT_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "❌ 错误: Bot 名称只允许包含小写字母、数字、下划线和连字符！"
  exit 1
fi

if [ "$BOT_NAME" = "_base" ]; then
  echo "❌ 错误: '_base' 为系统保留目录名称，不可使用！"
  exit 1
fi

TARGET_DIR="$BOTS_DIR/$BOT_NAME"

if [ -d "$TARGET_DIR" ]; then
  echo "⚠️ 警告: Bot '$BOT_NAME' 目录已存在 ($TARGET_DIR)"
  exit 1
fi

echo "🚀 正在初始化子 Bot: $BOT_NAME ..."
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# 1. 建立共享软链接（复用鉴权、模型端点和已安装的 200+ npm 依赖包）
ln -sf ../_base/npm npm
ln -sf ../_base/auth.json auth.json
ln -sf ../_base/models.json models.json
ln -sf ../_base/antigravity-accounts.json antigravity-accounts.json
ln -sf ../_base/models-store.json models-store.json

# 2. 继承基础配置模版
cp "$BASE_DIR/settings.base.json" settings.json

# 3. 生成专属 AGENTS.md 灵魂定义模版
cat <<EOF > AGENTS.md
# $BOT_NAME 核心准则与灵魂定义

$BOT_DESC

## 一、角色特质与思考范式
- **定位**：明确你的核心专长与任务边界。
- **风格**：定义你的回答风格、推理深度与代码品味。

## 二、工作规范与底线
- 严格遵循代码质量标准，不随意引入多余依赖。
- 修改代码前先排查定位，确保方案因果链条严密。

## 三、记忆与交付准则
- 交付清晰明了的变更与方案说明。
EOF

# 4. 自动注册终端别名到 ~/.zshrc
ZSHRC="$HOME/.zshrc"
ALIAS_CMD="alias pi-${BOT_NAME}=\"PI_CODING_AGENT_DIR=$TARGET_DIR pi\""

if [ -f "$ZSHRC" ]; then
  if ! grep -q "alias pi-${BOT_NAME}=" "$ZSHRC"; then
    echo "$ALIAS_CMD" >> "$ZSHRC"
    echo "✅ 已向 ~/.zshrc 添加别名: pi-$BOT_NAME"
  fi
fi

echo "🎉 子 Bot '$BOT_NAME' 创建成功！"
echo "📂 目录路径: $TARGET_DIR"
echo "⚡ 依赖包状态: 已零拷贝复用 _base 基础依赖（无需重新 npm install）"
echo "👉 启动方式: 运行 'source ~/.zshrc && pi-$BOT_NAME' 或:"
echo "   PI_CODING_AGENT_DIR=$TARGET_DIR pi"
