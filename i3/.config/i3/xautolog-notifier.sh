#!/usr/bin/env bash
set -euo pipefail

# --- GUI-Umgebung sicherstellen (wichtig für Autostarts) ---
export DISPLAY="${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

TITLE="Bildschirm wird bald gesperrt"
MSG="Der Bildschirm sperrt sich in 30 Sekunden."
ID=424242   # stabile ID, damit wir gezielt canceln können

# --- Notification senden ---
if command -v /usr/bin/dunstify >/dev/null 2>&1; then
  /usr/bin/dunstify -r "$ID" -a "Idle" -u normal -t 30000 \
    -h string:x-dunst-stack-tag:idlelock \
    "Bildschirm wird bald gesperrt" "$MSG"
else
  # Fallback: notify-send kann nicht gezielt gecancelt werden
  /usr/bin/notify-send -u normal -t 30000 "$TITLE" "$MSG"
fi

# --- Eingabe-Aktivität überwachen und Meldung schließen ---
# Sobald irgendein Eingabe-Event kommt, canceln wir die dunst-Meldung.
# 'timeout 30s' sorgt dafür, dass der Listener nach 30s sicher endet.
if command -v /usr/bin/xinput >/dev/null 2>&1 && command -v /usr/bin/dunstify >/dev/null 2>&1; then
  ( /usr/bin/timeout 30s /usr/bin/xinput test-xi2 --root | /usr/bin/head -n1 >/dev/null \
      && /usr/bin/dunstify -C "$ID" ) &
fi

exit 0




