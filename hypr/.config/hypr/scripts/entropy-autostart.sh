#!/usr/bin/env bash
# Start Entropy minimized for Live Features (time/volume/media).
# Layout sync on Hyprland Wayland is handled by eh-layout-sync.sh.
set -uo pipefail

APP="${HOME}/Applications/Entropy.AppImage"
[[ -x "$APP" ]] || APP="$(command -v entropy || true)"
[[ -n "${APP:-}" && -x "$APP" ]] || exit 0

# Already running? Match the AppImage path only.
if pgrep -u "$USER" -f '/Applications/Entropy\.AppImage' >/dev/null 2>&1; then
  exit 0
fi

sleep 2
nohup "$APP" --minimized >/dev/null 2>&1 &
disown
