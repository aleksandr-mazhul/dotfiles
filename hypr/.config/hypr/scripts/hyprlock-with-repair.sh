#!/usr/bin/env bash
# Lock, then repair session helpers that often die/desync after unlock.
set -uo pipefail
pidof hyprlock >/dev/null 2>&1 || hyprlock
exec "$HOME/.config/hypr/scripts/session-unlock-repair.sh"
