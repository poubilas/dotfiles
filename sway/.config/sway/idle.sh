#!/usr/bin/env bash
# idle.sh – Bildschirm-Timeout für Sway
# Verwendung: idle.sh <minuten> | idle.sh never | idle.sh status
#
# Verhalten:
#   - 30s vor Timeout: Warnhinweis via dunstify (verschwindet bei Aktivität)
#   - Nach Timeout:    Bildschirm aus (DPMS off)
#   - Bei Aktivität:   Bildschirm an, Warnhinweis schließen
set -euo pipefail

NOTIF_ID=424242

stop_idle() {
  pkill -x swayidle || true
}

start_idle() {
  local minutes="$1"
  local t_warn=$(( minutes * 60 - 30 ))
  local t_off=$(( minutes * 60 ))

  stop_idle
  swayidle -w \
    timeout "$t_warn" \
      "dunstify -r $NOTIF_ID -u normal -t 30000 \
        'Bildschirm wird ausgeschaltet' \
        'Noch 30 Sekunden bis der Bildschirm ausgeht.'" \
    resume \
      "dunstify -C $NOTIF_ID" \
    timeout "$t_off" \
      'swaymsg "output * dpms off"' \
    resume \
      'swaymsg "output * dpms on"' \
    2>/dev/null &
}

status_idle() {
  if pgrep -x swayidle >/dev/null; then
    local t
    t="$(pgrep -a swayidle | grep -oP 'timeout \K[0-9]+' | sort -n | tail -n1)"
    echo "Bildschirm-Timeout aktiv: $(( t / 60 )) Minuten"
  else
    echo "Bildschirm-Timeout deaktiviert"
  fi
}

case "${1:-status}" in
  never|off)
    stop_idle
    echo "Bildschirm-Timeout deaktiviert"
    ;;
  status)
    status_idle
    ;;
  ""|help|-h|--help)
    echo "Verwendung: idle.sh never | idle.sh <minuten> | idle.sh status"
    exit 0
    ;;
  *)
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 1 ]; then
      start_idle "$1"
      echo "Bildschirm-Timeout nach $1 Minuten (Warnung nach $(( $1 - 1 )) min 30s)"
    else
      echo "Ungültig. Mindestens 2 Minuten. Verwende: idle.sh never | idle.sh <minuten>" >&2
      exit 1
    fi
    ;;
esac
