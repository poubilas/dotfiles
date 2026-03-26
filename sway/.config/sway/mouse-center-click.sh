#!/usr/bin/env bash
# mouse-center-click.sh – Maus an Mitte des aktuellen Outputs
# Cursor-Bewegung via swaymsg (logische Koordinaten), Klick via ydotool
set -euo pipefail

out_name="$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused==true) | .output')"
[ -z "$out_name" ] && exit 0

read -r offx offy mw mh < <(
  swaymsg -t get_outputs \
  | jq -r --arg O "$out_name" '.[] | select(.name==$O) | "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"'
)

# X: Mitte des Outputs
x_local=$(( mw / 2 ))
# Y: 62% der Bildschirmhöhe
y_local=$(( mh * 62 / 100 ))

absx=$(( offx + x_local ))
absy=$(( offy + y_local ))

swaymsg "seat seat0 cursor set $absx $absy"
sleep 0.05
swaymsg "seat seat0 cursor press button1"
sleep 0.05
swaymsg "seat seat0 cursor release button1"
