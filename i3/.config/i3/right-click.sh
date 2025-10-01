#!/usr/bin/env bash
set -euo pipefail

# Auflösung des Primary-Displays holen (z.B. "2560x1440")
res="$(xrandr --query | awk '/ primary/{print $4}' | cut -d+ -f1)"
w="${res%x*}"

case "$res" in
  1920x1080) x=1844; y=667 ;;   # Full HD
  2560x1440) x=2540; y=667 ;;   # 2K / QHD
  3840x2160) x=3820; y=667 ;;   # 4K (nahe rechter Rand)
  *)          x=$((w - 76)); y=667 ;;  # Fallback: 76 px vom rechten Rand
esac

xdotool mousemove "$x" "$y" click 1 --clearmodifiers 1
