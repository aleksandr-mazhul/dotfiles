#!/usr/bin/env bash
# Session startup: Windscribe best location + daily apps.
set -uo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"

(
  # Helper/network may still be coming up right after login
  sleep 2
  if "$CLI" connect best; then
    command -v notify-send >/dev/null && notify-send -a Windscribe "VPN" "Connected (best location)"
  fi
) &

# Let the compositor settle before spawning windows
sleep 0.5
Telegram >/dev/null 2>&1 &
cursor >/dev/null 2>&1 &
kitty >/dev/null 2>&1 &
