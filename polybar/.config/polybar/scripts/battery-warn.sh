#!/bin/bash
# Sendet eine Warnung wenn der Akku unter 10% fällt.
# Verhindert Spam: nur eine Benachrichtigung pro Entlade-Ereignis.

WARNED=0

while true; do
    CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)

    if [[ "$STATUS" == "Discharging" && "$CAPACITY" -le 10 && "$WARNED" -eq 0 ]]; then
        notify-send -u critical -t 0 "Akkuwarnung" "Akku bei ${CAPACITY}% – bitte laden!"
        WARNED=1
    elif [[ "$CAPACITY" -gt 10 || "$STATUS" != "Discharging" ]]; then
        WARNED=0
    fi

    sleep 60
done
