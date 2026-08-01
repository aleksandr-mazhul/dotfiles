#!/usr/bin/env bash
# Apply wallpaper via swww + matugen theme pipeline (Quickshell wallpaper panel)
# Usage: qs-apply-wallpaper.sh <path> [path...]
# With multiple paths: apply the first, save the full batch for wallpaper-random.
set -euo pipefail

if (($# < 1)); then
  echo "usage: qs-apply-wallpaper.sh <image> [image...]" >&2
  exit 1
fi

export PATH="${HOME}/.local/bin:/usr/bin:/bin:${PATH:-}"

batch_file="${XDG_CACHE_HOME:-$HOME/.cache}/qs-wallpaper-batch"
mkdir -p "$(dirname "$batch_file")"

paths=()
for p in "$@"; do
  [[ -n "$p" && -f "$p" ]] || continue
  paths+=("$p")
done
((${#paths[@]} > 0)) || exit 1

selected="${paths[0]}"

if ((${#paths[@]} > 1)); then
  printf '%s\n' "${paths[@]}" >"$batch_file"
else
  # Single apply clears a previous multi-select pool
  rm -f "$batch_file"
fi

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

if ((${#paths[@]} > 1)); then
  notify-send -a Wallpapers "Wallpaper set" "$(basename "$selected") (+$(( ${#paths[@]} - 1 )) more)" 2>/dev/null || true
else
  notify-send -a Wallpapers "Wallpaper set" "$(basename "$selected")" 2>/dev/null || true
fi
