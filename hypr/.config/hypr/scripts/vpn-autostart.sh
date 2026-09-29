#!/usr/bin/env bash
# Connect Windscribe ASAP on Hyprland start (no initial delay).
# Retries while the helper / network come up.
# Never passes the CLI token "best": that is Windscribe's own node, which can
# be in Russia. Connect the lowest positive ping outside region Russia.
set -uo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICK="$HERE/vpn-pick-location"
PING_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rice/vpn-pings.cache"

already_connected() {
  local st
  st="$("$CLI" status 2>/dev/null || true)"
  [[ "${st,,}" == *"connect state: connected"* ]]
}

(
  refreshed=0
  for _ in $(seq 1 40); do
    if already_connected; then
      exit 0
    fi

    loc=""
    ping=""
    cleanup=""
    if [[ -n "${VPN_LOCATIONS_FILE:-}" && -n "${VPN_PINGS_FILE:-}" ]]; then
      loc="$VPN_LOCATIONS_FILE"
      ping="$VPN_PINGS_FILE"
    else
      loc="$(mktemp)"
      cleanup="$loc"
      "$CLI" locations >"$loc" 2>/dev/null || true
      if [[ ! -s "$PING_CACHE" && "$refreshed" -eq 0 ]]; then
        refreshed=1
        "$HERE/qs-vpn.sh" ping-refresh >/dev/null 2>&1 || true
      fi
      ping="$PING_CACHE"
    fi

    city=""
    if [[ -n "$loc" && -f "$loc" && -n "$ping" && -f "$ping" ]]; then
      city="$("$PICK" --locations "$loc" --pings "$ping" 2>/dev/null)" || city=""
    fi
    [[ -n "$cleanup" ]] && rm -f "$cleanup"

    if [[ -n "$city" ]] && "$CLI" connect "$city" >/dev/null 2>&1; then
      if command -v notify-send >/dev/null; then
        notify-send -a Windscribe "VPN" "Connected ($city)"
      fi
      exit 0
    fi
    sleep 0.4
  done
) &
