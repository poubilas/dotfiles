#!/usr/bin/env bash
set -euo pipefail

# Voraussetzung: jq (pacman -S jq)

# 1) fokussierten Workspace -> Output-Name (z. B. "HDMI-1", "eDP-1")
out_name="$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused==true) | .output')"
[ -z "$out_name" ] && exit 0

# 2) Rechteck (x,y,width,height) dieses Outputs holen
read -r offx offy mw mh < <(
  i3-msg -t get_outputs \
  | jq -r --arg O "$out_name" '.[] | select(.name==$O) | "\(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height)"'
)

# 3) größtes passendes X innerhalb dieses Outputs (4K -> 2K -> FHD -> Fallback)
choose_x() {
  local w="$1"
  if  (( w > 3820 )); then echo 3820      # 4K
  elif (( w > 2540 )); then echo 2540     # 2K/QHD
  elif (( w > 1844 )); then echo 1844     # FHD
  else echo $(( w - 76 ))                 # 76 px vom rechten Rand
  fi
}

x_local="$(choose_x "$mw")"
y_local=667

absx=$(( offx + x_local ))
absy=$(( offy + y_local ))

# Optionales Debug:
# echo "$(date '+%F %T') out=$out_name rect=($offx,$offy,$mw,$mh) -> ($absx,$absy)" >> "$HOME/.cache/right-click.log"

# 4) Maus bewegen & klicken (deine Syntax)
xdotool mousemove "$absx" "$absy" click 1 --clearmodifiers 1

