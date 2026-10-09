#!/bin/sh

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

# 1. 核心加速：单次 IPC 查询所有窗口与其工作区和应用名 (40ms vs 550ms!)
ALL_WINDOWS=$(aerospace list-windows --all --format "%{workspace}|%{app-name}" 2>/dev/null)

# 2. 在内存中聚合每个工作区的应用图标
# 预定义所有支持的工作区
ALL_SPACES=("0" "1" "2" "3" "4" "5" "6" "E" "M" "Q" "R" "W")

# 准备一个批量更新的 sketchybar 命令参数数组
BATCH_ARGS=()

for sid in "${ALL_SPACES[@]}"; do
  # 提取该工作区的应用
  apps=$(echo "$ALL_WINDOWS" | grep "^${sid}|" | cut -d'|' -f2)

  icon_str=""
  is_occupied=false
  if [ -n "$apps" ]; then
    is_occupied=true
    while IFS= read -r app; do
      [ -z "$app" ] && continue
      icon_result=""
      __icon_map "$app"
      if [ -n "$icon_result" ]; then
        if [ -z "$icon_str" ]; then
          icon_str="$icon_result"
        else
          icon_str="$icon_str $icon_result"
        fi
      fi
    done <<< "$apps"
  fi

  if [ "$sid" = "$FOCUSED" ]; then
    BATCH_ARGS+=(
      --set "space.$sid"
      drawing=on
      background.drawing=on
      background.color="$ITEM_ACTIVE_BG"
      background.corner_radius=6
      background.height=22
      icon.color="$ITEM_ACTIVE_TEXT"
      label.color="$ITEM_ACTIVE_TEXT"
      label="$icon_str"
    )
  elif [ "$is_occupied" = "true" ]; then
    BATCH_ARGS+=(
      --set "space.$sid"
      drawing=on
      background.drawing=off
      icon.color="$TEXT"
      label.color="$SUBTEXT0"
      label="$icon_str"
    )
  else
    BATCH_ARGS+=(
      --set "space.$sid"
      drawing=off
    )
  fi
done

# 3. 核心加速：一次性提交所有修改，绝不循环调用 sketchybar
if [ ${#BATCH_ARGS[@]} -gt 0 ]; then
  sketchybar "${BATCH_ARGS[@]}"
fi
