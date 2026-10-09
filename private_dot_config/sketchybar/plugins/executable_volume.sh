#!/bin/sh

source "$CONFIG_DIR/colors.sh"

VOLUME="$INFO"
if [ -z "$VOLUME" ]; then
  VOLUME=$(osascript -e "output volume of (get volume settings)")
fi

MUTED=$(osascript -e "output muted of (get volume settings)")

if [ "$MUTED" = "true" ] || [ "$VOLUME" -eq 0 ]; then
  ICON="󰝟"
  COLOR="$OVERLAY0"
elif [ "$VOLUME" -gt 60 ]; then
  ICON="󰕾"
  COLOR="$BLUE"
elif [ "$VOLUME" -gt 25 ]; then
  ICON="󰖀"
  COLOR="$SKY"
else
  ICON="󰕿"
  COLOR="$TEAL"
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${VOLUME}%" \
  label.color="$TEXT"
