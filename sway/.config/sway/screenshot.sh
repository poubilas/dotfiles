#!/usr/bin/env bash
# screenshot.sh – Screenshot mit grim + slurp (Wayland-nativ)
# Verwendung: screenshot.sh            → Ausschnitt → Zwischenablage
#             screenshot.sh save       → Ausschnitt → Datei in ~/Downloads
#             screenshot.sh full       → Vollbild   → Zwischenablage
#             screenshot.sh full save  → Vollbild   → Datei in ~/Downloads
set -euo pipefail

TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
OUTFILE="$HOME/Downloads/screenshot_${TIMESTAMP}.png"

if [ "${1:-}" = "full" ]; then
    if [ "${2:-}" = "save" ]; then
        grim "$OUTFILE"
        notify-send "Screenshot gespeichert" "$OUTFILE"
    else
        grim - | wl-copy
        notify-send "Screenshot" "Vollbild in Zwischenablage kopiert"
    fi
elif [ "${1:-}" = "save" ]; then
    slurp | grim -g - "$OUTFILE"
    notify-send "Screenshot gespeichert" "$OUTFILE"
else
    slurp | grim -g - - | wl-copy
    notify-send "Screenshot" "In Zwischenablage kopiert"
fi
