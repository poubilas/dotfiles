#!/usr/bin/env bash
set -euo pipefail

out_name="$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true) | .output')"
[ -z "$out_name" ] && exit 0

read -r offx offy mw mh < <(
  i3-msg -t get_outputs \
  | jq -r --arg O "$out_name" '.[] | select(.name==$O) | "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"'
)

x_local=$(( mw / 2 ))
y_local=667

absx=$(( offx + x_local ))
absy=$(( offy + y_local ))

xdotool mousemove "$absx" "$absy" click 1 --clearmodifiers 1

