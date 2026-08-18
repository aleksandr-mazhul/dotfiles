#!/usr/bin/env bash
# Region screenshot → file + clipboard + cliphist (so it shows in Clipboard UI)
set -euo pipefail

dir="$HOME/pictures/screenshots"
mkdir -p "$dir"

tmp="$(mktemp "$dir/shot-XXXXXX.png")"
if ! hyprshot -m region -r >"$tmp"; then
  rm -f "$tmp"
  exit 0
fi
if [[ ! -s "$tmp" ]]; then
  rm -f "$tmp"
  exit 0
fi

final="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"
mv -f "$tmp" "$final"

wl-copy -t image/png <"$final"
cliphist store <"$final"

notify-send -a hyprshot -i "$final" -n camera-photo -u low -t 2000 -e \
  -r 424202 \
  -h string:desktop-entry:hyprshot \
  -- "Screenshot" "Saved" 2>/dev/null || true
