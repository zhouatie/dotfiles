#!/bin/sh

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
ALL_WINDOWS=$(aerospace list-windows --all --format "%{workspace}|%{app-name}" 2>/dev/null)

ALL_SPACES=("0" "1" "2" "3" "4" "5" "6" "E" "M" "Q" "R" "W")
BATCH_ARGS=()

for sid in "${ALL_SPACES[@]}"; do
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

if [ ${#BATCH_ARGS[@]} -gt 0 ]; then
  sketchybar "${BATCH_ARGS[@]}"
fi
