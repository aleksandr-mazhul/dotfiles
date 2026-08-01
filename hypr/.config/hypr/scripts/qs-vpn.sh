#!/usr/bin/env bash
# Windscribe helpers for Quickshell VPN panel
set -euo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"
cmd="${1:-}"

notify() {
  command -v notify-send >/dev/null && notify-send -a Windscribe "$1" "${2:-}" || true
}

status_line() {
  local st conn loc
  st="$("$CLI" status 2>/dev/null || true)"
  conn="$(printf '%s\n' "$st" | awk -F': ' '/Connect state:/{print $2; exit}')"
  loc="$(printf '%s\n' "$st" | awk -F': ' '/Location:/{print $2; exit}')"
  if [[ "${conn,,}" == *connected* && -n "${loc:-}" ]]; then
    echo "● Connected: $loc"
  else
    echo "○ Disconnected"
  fi
}

case "$cmd" in
  status)
    status_line
    ;;
  locations)
    "$CLI" locations 2>/dev/null | sed 's/ (Disabled).*//; s/ ([0-9].*//' || true
    ;;
  disconnect)
    notify "Disconnecting…"
    "$CLI" disconnect
    notify "Disconnected"
    ;;
  best)
    notify "Connecting…" "Best location"
    "$CLI" connect best
    notify "Connected" "$(status_line)"
    ;;
  connect)
    loc="${2:-}"
    [[ -n "$loc" ]] || exit 1
    notify "Connecting…" "$loc"
    if "$CLI" connect "$loc"; then
      notify "Connected" "$loc"
    else
      city="${loc##* - }"
      if "$CLI" connect "$city"; then
        notify "Connected" "$city"
      else
        notify "Failed" "$loc"
        exit 1
      fi
    fi
    ;;
  *)
    echo "usage: $0 status|locations|disconnect|best|connect <location>" >&2
    exit 2
    ;;
esac
