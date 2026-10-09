#!/bin/sh

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

APP="$INFO"
if [ -z "$APP" ]; then
  APP=$(aerospace list-windows --focused --format "%{app-name}" 2>/dev/null)
fi

WINDOW_TITLE=$(aerospace list-windows --focused --format "%{window-title}" 2>/dev/null)

if [ -n "$APP" ]; then
  icon_result=""
  __icon_map "$APP"

  if [ -n "$WINDOW_TITLE" ]; then
    # 限制标题长度
    if [ ${#WINDOW_TITLE} -gt 35 ]; then
      WINDOW_TITLE="$(echo "$WINDOW_TITLE" | cut -c 1-32)…"
    fi
    DISPLAY_TEXT="$WINDOW_TITLE"
  else
    DISPLAY_TEXT="$APP"
  fi

  sketchybar --set "$NAME" \
    drawing=on \
    icon="$icon_result" \
    icon.color="$MAUVE" \
    label="$DISPLAY_TEXT" \
    label.color="$TEXT"
else
  sketchybar --set "$NAME" drawing=off
fi
