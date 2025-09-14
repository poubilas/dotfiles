#!/bin/sh
# Deaktiviert externe Ausgänge NUR auf Geräten mit internem Panel (Laptop).
# Auf Desktops (ohne eDP/LVDS/DSI) macht es nichts.

INT=$(xrandr --query | awk '/ connected/{print $1}' | grep -E '^(eDP|LVDS|DSI)-' | head -n1)

if [ -n "$INT" ]; then
  for OUT in $(xrandr --query | awk '/ connected/{print $1}' | grep -v "^$INT$"); do
    xrandr --output "$OUT" --off 2>/dev/null || true
  done
  xrandr --output "$INT" --auto --primary --pos 0x0
fi

