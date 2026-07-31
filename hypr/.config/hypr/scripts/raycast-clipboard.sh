#!/usr/bin/env bash
# Raycast-like clipboard history: search → Enter pastes into the active app
set -euo pipefail

if ! command -v cliphist >/dev/null || ! command -v wofi >/dev/null; then
  exit 1
fi

selection="$(cliphist list | wofi --dmenu -i -p 'Clipboard' 2>/dev/null || true)"
[[ -z "${selection}" ]] && exit 0

# Put chosen entry back on the clipboard (text or image)
printf '%s' "${selection}" | cliphist decode | wl-copy

# Small delay so focus returns to the previous window after wofi closes
sleep 0.08

# Paste into the focused app (Linux default; matches Raycast primary action)
if command -v wtype >/dev/null; then
  wtype -M ctrl -k v -m ctrl
fi
