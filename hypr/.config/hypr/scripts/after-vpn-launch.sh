#!/usr/bin/env bash
# Launch an app on a workspace only once Windscribe reports "Connected".
# Usage: after-vpn-launch.sh <workspace> <command...>
# Polls up to $VPN_WAIT_SECS (default 300); gives up (with a notification) if
# the VPN never comes up, so the app is not opened without it.
set -uo pipefail

ws="${1:?workspace}"
shift
cmd="$*"
[[ -n "$cmd" ]] || exit 1

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/session-autostart.log"
bin="${cmd%% *}"

vpn_connected() {
  local st
  st="$(timeout 5 "$CLI" status 2>/dev/null || true)"
  [[ "${st,,}" == *"connect state: connected"* ]]
}

for ((i = 0; i < ${VPN_WAIT_SECS:-300}; i++)); do
  if vpn_connected; then
    # Already running (manual launch while we waited) → nothing to do.
    pgrep -x "$bin" >/dev/null 2>&1 && exit 0
    echo "after-vpn-launch: VPN up, spawn $cmd ws=$ws" >>"$LOG"
    hyprctl eval "hl.exec_cmd([=[${cmd}]=], { workspace = [=[${ws} silent]=] })" >/dev/null 2>&1
    exit 0
  fi
  sleep 1
done

echo "after-vpn-launch: VPN never connected, skip $cmd" >>"$LOG"
command -v notify-send >/dev/null && notify-send -a Autostart "$bin not started" "VPN did not connect"
exit 0
