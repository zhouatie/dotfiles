#!/usr/bin/env bash
set -e

# ==============================================================================
# Pi-Bots 调度器: 供主 Agent 或人类一键调度指定的独立子 Bot
# 用法: call-bot.sh <bot-name> <task-prompt>
# 示例: call-bot.sh raven "排查当前代码的并发死锁"
# ==============================================================================

BOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ 错误: 参数不足！"
  echo "用法: $0 <bot-name> <task-prompt>"
  echo ""
  echo "当前可用的子 Bot 列表:"
  for dir in "$BOTS_DIR"/*/; do
    bname="$(basename "$dir")"
    if [ "$bname" != "_base" ] && [ -f "$dir/settings.json" ]; then
      echo "  - $bname"
    fi
  done
  exit 1
fi

BOT_NAME="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
TASK="$2"
TARGET_DIR="$BOTS_DIR/$BOT_NAME"

if [ ! -d "$TARGET_DIR" ] || [ ! -f "$TARGET_DIR/settings.json" ]; then
  echo "❌ 错误: 子 Bot '$BOT_NAME' 不存在！($TARGET_DIR)"
  echo "可用 Bot:"
  for dir in "$BOTS_DIR"/*/; do
    bname="$(basename "$dir")"
    if [ "$bname" != "_base" ] && [ -f "$dir/settings.json" ]; then
      echo "  - $bname"
    fi
  done
  exit 1
fi

# 执行子 Bot，继承当前终端的工程目录 CWD，但隔离 Bot 专属配置
PI_CODING_AGENT_DIR="$TARGET_DIR" pi -p "$TASK"
