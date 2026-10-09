#!/bin/sh

source "$CONFIG_DIR/colors.sh"

FOCUSED="$FOCUSED_WORKSPACE"
if [ -z "$FOCUSED" ]; then
  FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
fi

# 瞬间完成高亮状态切换（< 10ms，零延迟瞬发响应！）
sketchybar \
  --set '/space\..*/' background.drawing=off icon.color="$TEXT" label.color="$SUBTEXT0" \
  --set "space.$FOCUSED" drawing=on background.drawing=on background.color="$ITEM_ACTIVE_BG" background.corner_radius=6 background.height=22 icon.color="$ITEM_ACTIVE_TEXT" label.color="$ITEM_ACTIVE_TEXT"

# 异步同步应用图标增减（不阻塞工作区瞬间响应）
"$CONFIG_DIR/plugins/aerospace_apps.sh" >/dev/null 2>&1 &
