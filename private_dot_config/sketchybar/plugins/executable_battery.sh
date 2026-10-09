#!/bin/sh

source "$CONFIG_DIR/colors.sh"

BATT_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATT_INFO" | grep -Eo "\d+%" | cut -d% -f1 | head -n1)
CHARGING=$(echo "$BATT_INFO" | grep 'AC Power')

if [ -z "$PERCENTAGE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

COLOR="$GREEN"
ICON="󰁹"

if [ -n "$CHARGING" ]; then
  ICON="󰂄"
  COLOR="$YELLOW"
elif [ "$PERCENTAGE" -le 20 ]; then
  ICON="󰁺"
  COLOR="$RED"
elif [ "$PERCENTAGE" -le 40 ]; then
  ICON="󰁼"
  COLOR="$PEACH"
elif [ "$PERCENTAGE" -le 60 ]; then
  ICON="󰁾"
  COLOR="$YELLOW"
elif [ "$PERCENTAGE" -le 80 ]; then
  ICON="󰂀"
  COLOR="$GREEN"
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${PERCENTAGE}%" \
  label.color="$TEXT" \
  drawing=on
