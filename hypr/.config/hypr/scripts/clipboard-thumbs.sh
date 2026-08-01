#!/usr/bin/env bash
# Decode cliphist image entries into thumbnails for Quickshell clipboard UI.
# Usage: clipboard-thumbs.sh <cache-dir>
set -euo pipefail

cache="${1:-${XDG_CACHE_HOME:-$HOME/.cache}/qs-clipboard-thumbs}"
mkdir -p "$cache"
# Drop stale thumbs older than a day
find "$cache" -type f -mtime +1 -delete 2>/dev/null || true

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  case "$line" in
    *hypr-clipboard-paste*|*"file:///tmp/hypr-clipboard"*) continue ;;
  esac
  if ! printf '%s' "$line" | rg -qi '\[\[\s*binary data|image/'; then
    continue
  fi
  id="${line%%$'\t'*}"
  [[ -z "$id" || "$id" == "$line" ]] && continue
  out="$cache/${id}.png"
  [[ -s "$out" ]] && continue
  if printf '%s\n' "$line" | cliphist decode >"$out.tmp" 2>/dev/null; then
    # Normalize to png via magick/ffmpeg if available, else keep raw bytes
    if command -v magick >/dev/null 2>&1; then
      magick "$out.tmp" -resize '160x96>' "$out" 2>/dev/null && rm -f "$out.tmp" || mv -f "$out.tmp" "$out"
    elif command -v convert >/dev/null 2>&1; then
      convert "$out.tmp" -resize '160x96>' "$out" 2>/dev/null && rm -f "$out.tmp" || mv -f "$out.tmp" "$out"
    else
      mv -f "$out.tmp" "$out"
    fi
  else
    rm -f "$out.tmp"
  fi
done < <(cliphist list 2>/dev/null || true)

printf '%s\n' "$cache"
