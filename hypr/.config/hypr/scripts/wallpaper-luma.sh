#!/usr/bin/env bash
# Print Rec.709 luma of the current wallpaper (0.000–1.000).
# Used by rice AdaptiveContrast; stdout must be a single number.
set -euo pipefail

wall=""

if command -v swww >/dev/null 2>&1; then
  wall="$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -1 || true)"
fi

if [[ -z "${wall}" || ! -f "${wall}" ]]; then
  ini="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"
  if [[ -f "${ini}" ]]; then
    wall="$(awk -F= '/^[[:space:]]*wallpaper[[:space:]]*=/{sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); print $2; exit}' "${ini}")"
    wall="${wall/#\~/$HOME}"
  fi
fi

if [[ -z "${wall}" || ! -f "${wall}" ]]; then
  printf '0.22\n'
  exit 0
fi

magick "${wall}" -resize 48x48! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info:
printf '\n'
