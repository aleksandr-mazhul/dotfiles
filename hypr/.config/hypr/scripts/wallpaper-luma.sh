#!/usr/bin/env bash
# Print Rec.709 luma (0.000–1.000) of the wallpaper region behind the launcher
# (upper-center crop), mixed with the full-frame mean so captions at the
# bottom cannot hide a bright sky/cream field.
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

full="$(magick "${wall}" -resize 48x48! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info:)"
upper="$(magick "${wall}" -gravity North -crop 70%x48%+0+8% +repage -resize 32x32! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info:)"

python3 - "${full}" "${upper}" <<'PY'
import sys
full, upper = float(sys.argv[1]), float(sys.argv[2])
# Prefer the region the launcher sits on; never go below the full-frame mean.
luma = max(full, 0.35 * full + 0.65 * upper)
print(f"{min(1.0, max(0.0, luma)):.6f}")
PY
