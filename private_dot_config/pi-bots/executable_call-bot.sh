#!/usr/bin/env bash
set -e

# ==============================================================================
# Pi-Bots 调度器: 供主 Agent 或人类一键调度指定的独立子 Bot
# 用法:
#   call-bot.sh [--sync|--wait] <bot-name> <task-prompt...>
#   call-bot.sh [--sync|--wait] <task-prompt...> (自动推断 Bot)
#   call-bot.sh --split <bot-name> [task-prompt...] (强制 Herdr 分屏交互)
# 示例:
#   call-bot.sh --sync raven "排查当前代码的并发死锁" (同步等待并捕获输出)
#   call-bot.sh popo 部署 rn-mine (交互式/分屏)
# ==============================================================================

BOTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 解析模式标志位
SYNC_MODE=0
SPLIT_MODE=0

while [[ "$1" =~ ^- ]]; do
  case "$1" in
    --sync|--wait|-s|-w)
      SYNC_MODE=1
      shift
      ;;
    --split)
      SPLIT_MODE=1
      shift
      ;;
    -h|--help)
      echo "用法: $0 [--sync|--wait|--split] [bot-name] <task-prompt>"
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

FULL_INPUT="$*"

if [ -z "$FULL_INPUT" ]; then
  echo "❌ 错误: 参数为空！"
  echo "用法: $0 [bot-name] <task-prompt>"
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

# 尝试优先解析首个 token
FIRST_TOKEN="${FULL_INPUT%% *}"
FIRST_TOKEN_CLEAN="$(echo "${FIRST_TOKEN#pi-}" | tr '[:upper:]' '[:lower:]')"

if [ -d "$BOTS_DIR/$FIRST_TOKEN_CLEAN" ] && [ -f "$BOTS_DIR/$FIRST_TOKEN_CLEAN/settings.json" ] && [ "$FIRST_TOKEN_CLEAN" != "_base" ]; then
  BOT_NAME="$FIRST_TOKEN_CLEAN"
  if [ "$FIRST_TOKEN" = "$FULL_INPUT" ]; then
    TASK=""
  else
    TASK="${FULL_INPUT#* }"
  fi
else
  # 检查自然语言中是否显式提及特定 bot（如 "调用下 ops bot"、"让 popo bot" 等）
  MATCHED_BOT=""
  for b in master ops popo pm qa raven; do
    if [[ "$FULL_INPUT" =~ (pi-)?$b([[:space:]]+bot|bot)? ]]; then
      # 优先精确匹配包含 bot 名称的指令
      if [[ "$FULL_INPUT" =~ (调用|唤起|让|请)?[[:space:]]*(下)?[[:space:]]*(pi-)?$b([[:space:]]+bot|bot)?([，,：:])?[[:space:]]*(.*) ]]; then
        MATCHED_BOT="$b"
        REMAINDER="${BASH_REMATCH[6]}"
        if [ -n "$REMAINDER" ]; then
          TASK="$REMAINDER"
        fi
        break
      fi
    fi
  done

  if [ -n "$MATCHED_BOT" ]; then
    BOT_NAME="$MATCHED_BOT"
    [ -z "$TASK" ] && TASK="$FULL_INPUT"
  else
    # 未显式指定有效 Bot，按整体任务关键词自动匹配
    case "$FULL_INPUT" in
      *需求*|*PRD*|*prd*|*排期*)
        BOT_NAME="pm"
        ;;
      *测试*|*用例*|*bug*|*Bug*|*QA*|*qa*)
        BOT_NAME="qa"
        ;;
      *构建*|*打包*|*部署*|*发布*|*环境*|*ops*|*Ops*)
        BOT_NAME="ops"
        ;;
      *popo*|*POPO*|*群聊*|*群组*|*多维表格*)
        BOT_NAME="popo"
        ;;
      *)
        BOT_NAME="raven"
        ;;
    esac
    TASK="$FULL_INPUT"
  fi
fi

TARGET_DIR="$BOTS_DIR/$BOT_NAME"

# 1. 同步执行模式 (适用于 Master 调度、流水线串联或脚本调用，阻塞等待完成并返回标准输出)
if [ "$SYNC_MODE" -eq 1 ]; then
  if [ -z "$TASK" ]; then
    echo "❌ 错误: 同步模式 (--sync/--wait) 必须提供具体的任务描述 (task)！" >&2
    exit 1
  fi
  exec env PI_CODING_AGENT_DIR="$TARGET_DIR" pi -p --mode text "$TASK"
fi

# 2. Herdr 环境分流执行 (在当前 Tab 内分出新窗格，避免频繁切换 Tab)
if [ "$SPLIT_MODE" -eq 1 ] || [ "${HERDR_ENV:-}" = "1" ]; then
  CUR_PANE="$(herdr pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty' | tr -d '\r')"
  if [ -n "$CUR_PANE" ]; then
    BOT_LABEL="pi-$BOT_NAME"
    SPLIT_JSON=$(herdr pane split "$CUR_PANE" --direction right --cwd "$PWD" --focus 2>/dev/null)
    NEW_PANE=$(echo "$SPLIT_JSON" | jq -r '.result.pane.pane_id // .result.pane_id // empty' | tr -d '\r')

    if [ -n "$NEW_PANE" ]; then
      herdr pane rename "$NEW_PANE" "$BOT_LABEL" >/dev/null 2>&1 || true
      herdr pane wait-output "$NEW_PANE" --regex '\S' --source visible --timeout 15000 >/dev/null 2>&1 || true

      if [ -n "$TASK" ]; then
        TASK_FILE=$(mktemp -t "pi-bot-task-XXXXXX.md")
        printf "%s\n" "$TASK" > "$TASK_FILE"
        herdr pane run "$NEW_PANE" "PI_CODING_AGENT_DIR=\"$TARGET_DIR\" pi @$TASK_FILE"
        echo "🚀 已在当前 Tab 右侧新窗格启动 $BOT_LABEL (窗格: $NEW_PANE，任务: $TASK)"
      else
        herdr pane run "$NEW_PANE" "PI_CODING_AGENT_DIR=\"$TARGET_DIR\" pi"
        echo "🚀 已在当前 Tab 右侧新窗格启动 $BOT_LABEL (窗格: $NEW_PANE)"
      fi
      exit 0
    fi
  fi
fi

# 2. 非 Herdr 环境兜底交互式启动
if [ -n "$TASK" ]; then
  PI_CODING_AGENT_DIR="$TARGET_DIR" pi "$TASK"
else
  PI_CODING_AGENT_DIR="$TARGET_DIR" pi
fi
