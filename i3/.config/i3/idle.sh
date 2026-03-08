#!/usr/bin/env bash
set -euo pipefail

NOTIFIER="/home/patrick/dotfiles/i3/.config/i3/xautolog-notifier.sh"
LOCKER="systemctl suspend"

stop_idle() {
  pkill -x xautolock || true
}

start_idle() {
  local minutes="$1"
  stop_idle
  nohup xautolock \
    -detectsleep \
    -time "$minutes" \
    -notify 30 \
    -notifier "$NOTIFIER" \
    -locker "$LOCKER" \
    >/dev/null 2>&1 &
}

status_idle() {
  if pgrep -x xautolock >/dev/null; then
    echo "xautolock aktiv"
  else
    echo "Idle-Suspend deaktiviert"
  fi
}

case "${1:-status}" in
  never|off)
    stop_idle
    echo "Idle-Suspend deaktiviert"
    ;;
  status)
    status_idle
    ;;
  ""|help|-h|--help)
    echo "Verwendung: idle.sh never | idle.sh <minuten> | idle.sh status"
    exit 0
    ;;
  *)
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]; then
      start_idle "$1"
      echo "Idle-Suspend nach $1 Minuten"
    else
      echo "Ungueltig. Verwende: idle.sh never | idle.sh <minuten> | idle.sh status" >&2
      exit 1
    fi
    ;;
esac
