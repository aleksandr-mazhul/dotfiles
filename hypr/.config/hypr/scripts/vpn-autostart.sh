#!/usr/bin/env bash
# Connect Windscribe ASAP on Hyprland start (no initial delay).
# Retries while the helper / network come up.
set -uo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"

already_connected() {
  local st
  st="$("$CLI" status 2>/dev/null || true)"
  [[ "${st,,}" == *"connect state: connected"* ]]
}

(
  for _ in $(seq 1 40); do
    if already_connected; then
      exit 0
    fi
    if "$CLI" connect best >/dev/null 2>&1; then
      if command -v notify-send >/dev/null; then
        notify-send -a Windscribe "VPN" "Connected (best location)"
      fi
      exit 0
    fi
    sleep 0.4
  done
) &
