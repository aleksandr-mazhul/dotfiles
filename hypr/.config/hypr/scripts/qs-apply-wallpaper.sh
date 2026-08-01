#!/usr/bin/env bash
# Apply wallpaper via swww + matugen theme pipeline (Quickshell wallpaper panel)
set -euo pipefail

selected="${1:-}"
[[ -n "$selected" && -f "$selected" ]] || exit 1

export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH:-}"

killall -q hyprpaper 2>/dev/null || true
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  swww-daemon &
  sleep 0.4
fi

swww img "$selected" \
  --transition-type grow \
  --transition-duration 1.4 \
  --transition-fps 60

if [[ -x "${HOME}/.local/bin/apply-wallpaper-theme" ]]; then
  "${HOME}/.local/bin/apply-wallpaper-theme" "$selected" >/dev/null 2>&1 || true
fi

notify-send -a Wallpapers "Wallpaper set" "$(basename "$selected")" 2>/dev/null || true
