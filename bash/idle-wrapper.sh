#!/usr/bin/env bash
# idle-wrapper.sh – leitet an das richtige idle-Script weiter
# je nach Session (Wayland/Sway oder X11/i3)
if [ -n "$WAYLAND_DISPLAY" ]; then
    exec /home/patrick/dotfiles/sway/.config/sway/idle.sh "$@"
else
    exec /home/patrick/dotfiles/i3/.config/i3/idle.sh "$@"
fi
