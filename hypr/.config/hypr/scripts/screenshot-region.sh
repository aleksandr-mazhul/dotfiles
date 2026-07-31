#!/usr/bin/env bash
# Region screenshot → file + clipboard + cliphist (so it shows in Clipboard UI)
set -euo pipefail

dir="${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$dir"

# Capture raw PNG from hyprshot, fan-out to file/clipboard/history
tmp="$(mktemp "$dir/shot-XXXXXX.png")"
if ! hyprshot -m region -r >"$tmp"; then
  rm -f "$tmp"
  exit 1
fi

# Stable timestamped name
final="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
mv -f "$tmp" "$final"

wl-copy -t image/png <"$final"
cliphist store <"$final"

notify-send -a hyprshot "Screenshot" "Saved and copied:\n$final" -i "$final" -t 2500 2>/dev/null || true
