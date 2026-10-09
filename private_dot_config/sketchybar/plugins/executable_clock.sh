#!/bin/sh

source "$CONFIG_DIR/colors.sh"

sketchybar --set "$NAME" \
  icon="󰥔" \
  icon.color="$LAVENDER" \
  label="$(date '+%m/%d %H:%M')" \
  label.color="$TEXT"
