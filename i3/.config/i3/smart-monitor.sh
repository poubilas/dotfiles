#!/bin/sh

# Finde den primären internen Monitor (oft eDP-X oder LVDS-X)
INTERNAL_OUTPUT=$(xrandr | grep " connected" | grep -E -o "^(eDP-|LVDS-)[0-9]+")

# Finde den ersten angeschlossenen externen Monitor (HDMI oder DisplayPort)
EXTERNAL_OUTPUT=$(xrandr | grep " connected" | grep -E -o "^(HDMI-|DP-|DVI-)[0-9]+")

# Fall 1: Nur der interne Monitor ist aktiv (Laptop allein)
if [ -n "$INTERNAL_OUTPUT" ] && [ -z "$EXTERNAL_OUTPUT" ]; then
    xrandr --output "$INTERNAL_OUTPUT" --primary --auto --pos 0x0
fi

# Fall 2: Interner und externer Monitor sind aktiv (Laptop mit zweitem Bildschirm)
if [ -n "$INTERNAL_OUTPUT" ] && [ -n "$EXTERNAL_OUTPUT" ]; then
    xrandr --output "$INTERNAL_OUTPUT" --primary --auto --pos 0x0 \
           --output "$EXTERNAL_OUTPUT" --auto --right-of "$INTERNAL_OUTPUT"
fi

# Fall 3: Nur ein externer Monitor ist aktiv (Desktop-PC oder zugeklappter Laptop)
if [ -z "$INTERNAL_OUTPUT" ] && [ -n "$EXTERNAL_OUTPUT" ]; then
    xrandr --output "$EXTERNAL_OUTPUT" --primary --auto --pos 0x0
fi
