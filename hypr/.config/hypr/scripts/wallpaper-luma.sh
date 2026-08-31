#!/usr/bin/env bash
# Rec.709 luma 0.000–1.000 = max(wallpaper, optional live region).
# Optional $1 is grim geometry: "x,y WxH" (pixels under the popup, not glass).
set -euo pipefail

geom="${1:-}"

luma_of_file() {
  local img="$1"
  magick "${img}" -resize 48x48! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info:
}

wallpaper_luma() {
  local wall=""
  if command -v swww >/dev/null 2>&1; then
    wall="$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -1 || true)"
  fi
  if [[ -z "${wall}" || ! -f "${wall}" ]]; then
    local ini="${XDG_CONFIG_HOME:-$HOME/.config}/waypaper/config.ini"
    if [[ -f "${ini}" ]]; then
      wall="$(awk -F= '/^[[:space:]]*wallpaper[[:space:]]*=/{sub(/^[[:space:]]+/, "", $2); sub(/[[:space:]]+$/, "", $2); print $2; exit}' "${ini}")"
      wall="${wall/#\~/$HOME}"
    fi
  fi
  if [[ -z "${wall}" || ! -f "${wall}" ]]; then
    printf '0.22'
    return
  fi
  local full upper
  full="$(luma_of_file "${wall}")"
  upper="$(magick "${wall}" -gravity North -crop 70%x48%+0+8% +repage -resize 32x32! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info:)"
  python3 - "${full}" "${upper}" <<'PY'
import sys
full, upper = float(sys.argv[1]), float(sys.argv[2])
luma = max(full, 0.35 * full + 0.65 * upper)
print(f"{min(1.0, max(0.0, luma)):.6f}")
PY
}

region_luma() {
  local g="$1"
  if [[ -z "${g}" ]] || ! command -v grim >/dev/null 2>&1; then
    return 1
  fi
  grim -t ppm -g "${g}" - 2>/dev/null \
    | magick ppm:- -resize 32x32! -format '%[fx:mean.r*0.2126+mean.g*0.7152+mean.b*0.0722]' info: 2>/dev/null
}

wall="$(wallpaper_luma || printf '0.22')"
region=""
if [[ -n "${geom}" ]]; then
  region="$(region_luma "${geom}" || true)"
fi

python3 - "${wall}" "${region}" <<'PY'
import sys
wall = float(sys.argv[1])
raw = (sys.argv[2] or "").strip()
try:
    region = float(raw) if raw else None
except ValueError:
    region = None
luma = wall if region is None else max(wall, region)
print(f"{min(1.0, max(0.0, luma)):.6f}")
PY
