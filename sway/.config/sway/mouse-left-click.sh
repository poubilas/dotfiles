#!/usr/bin/env bash
# mouse-left-click.sh – Maus an linke Position des aktuellen Outputs
# Cursor-Bewegung via swaymsg (logische Koordinaten), Klick via ydotool
set -euo pipefail

out_name="$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused==true) | .output')"
[ -z "$out_name" ] && exit 0

read -r offx offy mw mh < <(
  swaymsg -t get_outputs \
  | jq -r --arg O "$out_name" '.[] | select(.name==$O) | "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"'
)

# X: 50px vom linken Rand
x_local=50
# Y: 62% der Bildschirmhöhe
y_local=$(( mh * 62 / 100 ))

absx=$(( offx + x_local ))
absy=$(( offy + y_local ))

swaymsg "seat seat0 cursor set $absx $absy"
ydotool click 0x110
