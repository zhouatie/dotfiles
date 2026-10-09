#!/bin/sh

source "$CONFIG_DIR/colors.sh"

BADGES=$(osascript -e '
tell application "System Events"
  tell process "Dock"
    set res to ""
    repeat with itm in (every UI element of list 1 whose name contains "POPO" or name contains "popo" or name contains "微信" or name contains "WeChat")
      try
        set aName to name of itm
        set aVal to value of attribute "AXStatusLabel" of itm
        if aVal is not missing value and aVal is not "" then
          set res to res & aName & ":" & aVal & ";"
        end if
      end try
    end repeat
    return res
  end tell
end tell' 2>/dev/null)

POPO_BADGE=""
WECHAT_BADGE=""

IFS=';'
for entry in $BADGES; do
  [ -z "$entry" ] && continue
  name="${entry%%:*}"
  val="${entry#*:}"
  case "$name" in
    *POPO*|*popo*)
      POPO_BADGE="$val"
      ;;
    *微信*|*WeChat*)
      WECHAT_BADGE="$val"
      ;;
  esac
done

# 更新 POPO 小胶囊
if [ -n "$POPO_BADGE" ]; then
  sketchybar --set messages.popo \
    drawing=on \
    icon="󰭹" \
    label="$POPO_BADGE" \
    label.color="$RED" \
    icon.color="$PEACH"
else
  sketchybar --set messages.popo drawing=off
fi

# 更新 微信 小胶囊
if [ -n "$WECHAT_BADGE" ]; then
  sketchybar --set messages.wechat \
    drawing=on \
    icon="󰘑" \
    label="$WECHAT_BADGE" \
    label.color="$RED" \
    icon.color="$GREEN"
else
  sketchybar --set messages.wechat drawing=off
fi
