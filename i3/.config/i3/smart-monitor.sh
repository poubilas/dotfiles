#!/bin/sh

# Finde angeschlossene Monitore
INTERNAL_OUTPUT=$(xrandr | grep " connected" | grep -E -o "^(eDP-|LVDS-)[0-9]+")
EXTERNAL_OUTPUT=$(xrandr | grep " connected" | grep -E -o "^(HDMI-|DP-|DVI-)[0-9]+")

# --- Konfigurationen ---

# Fall 1: Laptop mit externem Monitor
if [ -n "$INTERNAL_OUTPUT" ] && [ -n "$EXTERNAL_OUTPUT" ]; then
    # Schritt 1: Internen Monitor konfigurieren
    xrandr --output "$INTERNAL_OUTPUT" --primary --mode 1920x1080 --pos 0x0

    # Schritt 2: Kurze Pause, damit die erste Einstellung sicher angewendet wird
    sleep 2

    # Schritt 3: Externen Monitor dazuschalten und konfigurieren
    xrandr --output "$EXTERNAL_OUTPUT" --mode 3840x2160 --rate 30 --scale-from 2560x1440 --pos 1920x0 --filter bilinear

# Fall 2: Nur der interne Monitor des Laptops ist aktiv
elif [ -n "$INTERNAL_OUTPUT" ]; then
    xrandr --output "$INTERNAL_OUTPUT" --primary --auto --pos 0x0

# Fall 3: Nur ein externer Monitor ist aktiv (Desktop-PC oder zugeklappter Laptop)
elif [ -n "$EXTERNAL_OUTPUT" ]; then
    xrandr --output "$EXTERNAL_OUTPUT" --primary --auto --pos 0x0
fi
