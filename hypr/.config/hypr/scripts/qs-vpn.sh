#!/usr/bin/env bash
# Windscribe helpers for Quickshell VPN panel
set -euo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"
cmd="${1:-}"

notify() {
  command -v notify-send >/dev/null && notify-send -a Windscribe "$1" "${2:-}" || true
}

status_line() {
  local st conn_line loc
  st="$("$CLI" status 2>/dev/null || true)"
  # New CLI: "Connect state: Connected: Tallinn - Node" (location inline, no Location: line)
  # Old CLI: "Connect state: Connected" + "Location: Tallinn"
  conn_line="$(printf '%s\n' "$st" | sed -n 's/^Connect state: //p' | head -1)"
  loc="$(printf '%s\n' "$st" | sed -n 's/^Location: //p' | head -1)"
  if [[ "${conn_line,,}" == connected* ]]; then
    if [[ -z "${loc:-}" && "$conn_line" == Connected:* ]]; then
      loc="${conn_line#Connected: }"
      loc="${loc#"${loc%%[![:space:]]*}"}"
    fi
    echo "● Connected${loc:+: $loc}"
  else
    echo "○ Disconnected"
  fi
}

case "$cmd" in
  status)
    status_line
    ;;
  locations)
    # Output: connectKey|label  (unique cities + best)
    # Redirect CLI chatter; only keep clean key|label rows.
    "$CLI" locations 2>/dev/null | sed 's/ (Disabled).*//; s/ ([0-9].*$//' | awk -F' - ' '
      BEGIN { seen["best"]=1; print "best|Best location" }
      NF == 0 { next }
      tolower($0) ~ /already running|aborting|error:|spdlog|cli:/ { next }
      $1 ~ /^Best Location/ { next }
      {
        city = (NF >= 2 ? $2 : $1)
        gsub(/^ +| +$/, "", city)
        if (city == "" || seen[city]++) next
        if (city !~ /^[A-Za-z]/ ) next
        country = $1
        gsub(/^ +| +$/, "", country)
        label = (country != "" && country != city) ? (country " · " city) : city
        print city "|" label
      }
    ' || true
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
