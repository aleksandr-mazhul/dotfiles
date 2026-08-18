#!/usr/bin/env bash
# Full-monitor screenshot of what is on screen (GloView / menus / overlays).
set -euo pipefail

dir="$HOME/pictures/screenshots"
mkdir -p "$dir"

tmp="$(mktemp "$dir/shot-XXXXXX.png")"
out="$(hyprctl -j monitors | python3 -c 'import json,sys; print(next(m["name"] for m in json.load(sys.stdin) if m.get("focused")))')"
if ! grim -o "$out" "$tmp" || [[ ! -s "$tmp" ]]; then
  rm -f "$tmp"
  exit 0
fi

# Flash AFTER grim so the blink is not in the file. Foreground: Hyprland
# kills the exec cgroup when this script exits, so a background flash dies
# before it can map.
GDK_BACKEND=wayland ~/.config/hypr/scripts/screenshot-flash.py

final="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
mv -f "$tmp" "$final"

wl-copy -t image/png <"$final"
cliphist store <"$final"

notify-send -a hyprshot -i "$final" -n camera-photo -u low -t 2500 -e \
  -r 424202 \
  -h string:desktop-entry:hyprshot \
  -- "Screenshot" "Saved" 2>/dev/null || true
