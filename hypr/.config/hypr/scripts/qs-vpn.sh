#!/usr/bin/env bash
# Windscribe helpers for Quickshell VPN panel
set -euo pipefail

CLI="${WINDSCRIBE_CLI:-windscribe-cli}"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/qs-vpn.lock"
PENDING="${XDG_RUNTIME_DIR:-/tmp}/qs-vpn.pending"
JOBPID="${XDG_RUNTIME_DIR:-/tmp}/qs-vpn.job.pid"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rice"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rice"
CACHE="$CACHE_DIR/vpn-locations.cache"
PING_CACHE="$CACHE_DIR/vpn-pings.cache"
FAVS="$CONF_DIR/vpn-favorites"
TIMING_LOG="$CACHE_DIR/vpn-timing.log"
WS_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/Windscribe/Windscribe2.conf"
LOCATIONS_TIMEOUT="${VPN_LOCATIONS_TIMEOUT:-12}"
CLI_TIMEOUT="${VPN_CLI_TIMEOUT:-60}"
CACHE_MAX_AGE="${VPN_CACHE_MAX_AGE:-180}"
PING_MAX_AGE="${VPN_PING_MAX_AGE:-300}"
PROTO="${VPN_PROTOCOL:-wireguard}"
cmd="${1:-}"

notify() {
  command -v notify-send >/dev/null && notify-send -a Windscribe "$1" "${2:-}" || true
}

log_timing() {
  mkdir -p "$CACHE_DIR"
  printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$TIMING_LOG"
}

cli() {
  flock -w 10 "$LOCK" timeout "$CLI_TIMEOUT" "$CLI" "$@"
}

cli_status() {
  flock -n "$LOCK" timeout 5 "$CLI" status 2>/dev/null
}

set_pending() {
  printf '%s|%s|%s|%s\n' "$1" "${2:-}" "${3:-}" "$(date +%s)" >"$PENDING"
}

clear_pending() {
  rm -f "$PENDING"
}

clear_job() {
  rm -f "$JOBPID"
}

read_pending() {
  [[ -f "$PENDING" ]] || return 1
  local line action target label epoch now age
  line="$(cat "$PENDING" 2>/dev/null || true)"
  [[ -n "$line" ]] || return 1
  IFS='|' read -r action target label epoch <<<"$line"
  now="$(date +%s)"
  age=$((now - ${epoch:-0}))
  if (( age > 90 )); then
    clear_pending
    return 1
  fi
  printf '%s|%s|%s|%s\n' "$action" "$target" "$label" "$epoch"
}

status_line() {
  local st conn_line loc pend action target label

  if st="$(cli_status || true)" && [[ -n "${st:-}" ]]; then
    conn_line="$(printf '%s\n' "$st" | sed -n 's/^Connect state: //p' | head -1)"
    loc="$(printf '%s\n' "$st" | sed -n 's/^Location: //p' | head -1)"
    if [[ "${conn_line,,}" == connected* ]]; then
      if [[ -z "${loc:-}" && "$conn_line" == Connected:* ]]; then
        loc="${conn_line#Connected: }"
        loc="${loc#"${loc%%[![:space:]]*}"}"
      fi
      clear_pending
      echo "ON · ${loc:-connected}"
      return 0
    fi
    if pend="$(read_pending)"; then
      IFS='|' read -r action target label _ <<<"$pend"
      case "$action" in
        connect|best) echo "… Connecting${label:+: $label}"; return 0 ;;
        disconnect) echo "… Disconnecting"; return 0 ;;
      esac
    fi
    echo "OFF"
    return 0
  fi

  if pend="$(read_pending)"; then
    IFS='|' read -r action target label _ <<<"$pend"
    case "$action" in
      connect|best) echo "… Connecting${label:+: $label}" ;;
      disconnect) echo "… Disconnecting" ;;
      *) echo "…" ;;
    esac
    return 0
  fi

  echo "OFF"
}

# Merge CLI locations with ping cache → city|label|ping
parse_locations() {
  local ping_file="${1:-$PING_CACHE}"
  PING_FILE="$ping_file" python3 -c '
import os, re, sys

noise = re.compile(r"already running|aborting|error:|spdlog|cli:|===|OS Version|CLI pid|Started|Windscribe CLI is already running", re.I)
strip_disabled = re.compile(r"\s*\(Disabled\).*", re.I)
strip_speed = re.compile(r"\s*\(\d[^)]*\)\s*$")
city_ok = re.compile(r"^[\w][\w .'\''-]*$", re.UNICODE)

pings = {}
pf = os.environ.get("PING_FILE", "")
if pf and os.path.isfile(pf):
    with open(pf, encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or "|" not in line:
                continue
            parts = line.split("|")
            if len(parts) >= 2 and parts[1].isdigit():
                pings[parts[0].lower()] = parts[1]

raw = []
for line in sys.stdin:
    line = line.strip()
    if not line or noise.search(line):
        continue
    line = strip_disabled.sub("", line)
    line = strip_speed.sub("", line).strip()
    if line:
        raw.append(line)

best_node = ""
entries = []
seen = set()

for line in raw:
    low = line.lower()
    parts = [p.strip() for p in line.split(" - ") if p.strip()]
    if not parts:
        continue
    if low.startswith("best location"):
        if len(parts) >= 2:
            best_node = parts[1]
        continue
    if len(parts) >= 3:
        region, city, node = parts[0], parts[1], parts[2]
    elif len(parts) == 2:
        region, city, node = parts[0], parts[1], ""
    else:
        region = city = parts[0]
        node = ""
    key = city.lower()
    if not city or key in seen or not city_ok.match(city):
        continue
    seen.add(key)
    entries.append((city, region, node))

best_label = "Best location"
best_city = ""
if best_node:
    bn = best_node.lower()
    match = next((e for e in entries if e[2].lower() == bn), None)
    if match:
        city, region, _ = match
        best_city = city
        best_label = f"Best location ({region} · {city})" if region != city else f"Best location ({city})"
    else:
        best_label = f"Best location ({best_node})"

best_ping = pings.get(best_city.lower(), "") if best_city else ""
print(f"best|{best_label}|{best_ping}")
for city, region, _ in entries:
    label = f"{region} · {city}" if region != city else city
    ping = pings.get(city.lower(), "")
    print(f"{city}|{label}|{ping}")
'
}

# Probe Windscribe latency endpoints from GUI conf (official /latency RTT).
refresh_pings() {
  mkdir -p "$CACHE_DIR"
  local tmp
  tmp="$(mktemp)"
  WS_CONF="$WS_CONF" PING_OUT="$tmp" python3 - <<'PY' || true
import json, os, re, time, urllib.request, concurrent.futures
from pathlib import Path

conf_path = Path(os.environ["WS_CONF"])
out_path = Path(os.environ["PING_OUT"])
if not conf_path.is_file():
    raise SystemExit(0)

conf = conf_path.read_text(errors="latin1")
m = re.search(r'^wsnetSettings="(.*)"\s*$', conf, re.M)
if not m:
    raise SystemExit(0)
s = m.group(1).encode("utf-8").decode("unicode_escape")
outer = json.loads(s)
loc_raw = outer.get("locations")
locs = json.loads(loc_raw) if isinstance(loc_raw, str) else loc_raw
cities = {}
for region in locs.get("data", []):
    for g in region.get("groups", []):
        city = g.get("city")
        host = g.get("ping_host")
        if city and host and city not in cities:
            cities[city] = host

def rtt_ms(url, timeout=1.6):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            body = r.read().decode()
        j = json.loads(body)
        return int(round(float(j.get("rtt") or 0) / 1000))
    except Exception:
        return None

results = {}
with concurrent.futures.ThreadPoolExecutor(max_workers=32) as ex:
    futs = {ex.submit(rtt_ms, url): city for city, url in cities.items()}
    for fut in concurrent.futures.as_completed(futs):
        city = futs[fut]
        ms = fut.result()
        if ms is not None:
            results[city] = ms

now = int(time.time())
lines = [f"{city}|{ms}|{now}" for city, ms in sorted(results.items(), key=lambda kv: kv[1])]
out_path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
PY
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$PING_CACHE"
  else
    rm -f "$tmp"
  fi
}

cache_age() {
  local f="${1:-$CACHE}"
  [[ -f "$f" ]] || { echo 999999; return; }
  echo $(( $(date +%s) - $(stat -c %Y "$f" 2>/dev/null || echo 0) ))
}

refresh_locations_cache() {
  mkdir -p "$CACHE_DIR"
  local tmp
  tmp="$(mktemp)"
  {
    flock -w 3 "$LOCK" timeout "$LOCATIONS_TIMEOUT" "$CLI" locations 2>/dev/null || true
  } | parse_locations "$PING_CACHE" >"$tmp" || true
  if [[ -s "$tmp" ]] && [[ "$(grep -c '|' "$tmp" || true)" -gt 1 ]]; then
    cp "$tmp" "$CACHE"
  fi
  rm -f "$tmp"
}

emit_locations() {
  if [[ -f "$CACHE" ]] && [[ "$(grep -c '|' "$CACHE" || true)" -gt 1 ]]; then
    # Re-merge latest pings onto cached city list without waiting on CLI.
    if [[ -f "$PING_CACHE" ]]; then
      awk -F'|' -v PF="$PING_CACHE" '
        BEGIN {
          while ((getline line < PF) > 0) {
            split(line, a, "|")
            if (a[1] != "" && a[2] ~ /^[0-9]+$/)
              ping[tolower(a[1])] = a[2]
          }
          close(PF)
        }
        {
          key=$1; label=$2; p=$3
          if (key != "best") {
            lk = tolower(key)
            if (lk in ping) p = ping[lk]
          } else {
            # best|Best location (Region · City)|ping
            city = label
            sub(/^.*·[[:space:]]*/, "", city)
            sub(/\)[[:space:]]*$/, "", city)
            lk = tolower(city)
            if (lk in ping) p = ping[lk]
          }
          print key "|" label "|" p
        }
      ' "$CACHE"
    else
      cat "$CACHE"
    fi
  else
    echo "best|Best location|"
  fi
}

ensure_favs_dir() {
  mkdir -p "$CONF_DIR"
  [[ -f "$FAVS" ]] || : >"$FAVS"
}

list_favs() {
  ensure_favs_dir
  # city keys, one per line
  awk 'NF && $0 !~ /^#/' "$FAVS" 2>/dev/null || true
}

fav_toggle() {
  local city="${1:-}"
  [[ -n "$city" ]] || exit 1
  ensure_favs_dir
  local tmp norm
  norm="$(printf '%s' "$city" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  tmp="$(mktemp)"
  if grep -qixF "$norm" "$FAVS" 2>/dev/null; then
    grep -vixF "$norm" "$FAVS" >"$tmp" || true
    mv "$tmp" "$FAVS"
    echo "removed|$norm"
  else
    printf '%s\n' "$norm" >>"$FAVS"
    rm -f "$tmp"
    # unique preserve order
    awk 'NF && !seen[tolower($0)]++' "$FAVS" >"$tmp"
    mv "$tmp" "$FAVS"
    echo "added|$norm"
  fi
}

track_job() {
  echo $$ >"$JOBPID"
}

do_connect() {
  local loc="$1"
  local t0=$SECONDS
  if cli connect "$loc" "$PROTO" >/dev/null 2>&1; then
    log_timing "connect ok loc=$loc proto=$PROTO secs=$((SECONDS - t0))"
    return 0
  fi
  local alt=""
  if [[ "$loc" == *" - "* ]]; then
    alt="${loc##* - }"
    alt="${alt#"${alt%%[![:space:]]*}"}"
  fi
  if [[ -n "$alt" && "${alt,,}" != "${loc,,}" ]]; then
    if cli connect "$alt" "$PROTO" >/dev/null 2>&1; then
      log_timing "connect ok loc=$alt(alt) proto=$PROTO secs=$((SECONDS - t0))"
      return 0
    fi
  fi
  if cli connect "$loc" >/dev/null 2>&1; then
    log_timing "connect ok loc=$loc proto=auto secs=$((SECONDS - t0))"
    return 0
  fi
  log_timing "connect FAIL loc=$loc secs=$((SECONDS - t0))"
  return 1
}

case "$cmd" in
  status)
    status_line
    ;;
  pending)
    read_pending || true
    ;;
  favs)
    list_favs
    ;;
  fav-toggle)
    fav_toggle "${2:-}"
    ;;
  pings)
    # city|ms
    if [[ -f "$PING_CACHE" ]]; then
      awk -F'|' 'NF>=2 && $2 ~ /^[0-9]+$/ { print $1 "|" $2 }' "$PING_CACHE"
    fi
    ;;
  ping-refresh)
    refresh_pings
    # rewrite locations cache with new pings if we have city list
    if [[ -f "$CACHE" ]]; then
      emit_locations >"${CACHE}.new" && mv "${CACHE}.new" "$CACHE"
    fi
    ;;
  cancel)
    notify "Cancelling…"
    if [[ -f "$JOBPID" ]]; then
      job="$(cat "$JOBPID" 2>/dev/null || true)"
      if [[ -n "${job:-}" ]]; then
        pkill -P "$job" 2>/dev/null || true
        kill "$job" 2>/dev/null || true
      fi
    fi
    pkill -f '/windscribe-cli[[:space:]]+connect' 2>/dev/null || true
    pkill -f 'windscribe-cli[[:space:]]+connect' 2>/dev/null || true
    clear_pending
    clear_job
    flock -w 2 "$LOCK" timeout 12 "$CLI" disconnect >/dev/null 2>&1 || true
    log_timing "cancel"
    notify "Cancelled"
    ;;
  locations)
    mkdir -p "$CACHE_DIR"
    age="$(cache_age "$CACHE")"
    ping_age="$(cache_age "$PING_CACHE")"
    # Never block the UI on ping probes — serve cities immediately, refresh pings in bg.
    if [[ "$ping_age" -ge "$PING_MAX_AGE" ]]; then
      "$0" ping-refresh >/dev/null 2>&1 &
      disown || true
    fi
    if [[ -f "$CACHE" ]] && [[ "$age" -lt "$CACHE_MAX_AGE" ]] && [[ "$(grep -c '|' "$CACHE" || true)" -gt 1 ]]; then
      emit_locations
      refresh_locations_cache &
      disown || true
      exit 0
    fi
    refresh_locations_cache
    emit_locations
    ;;
  disconnect)
    track_job
    set_pending disconnect "" ""
    notify "Disconnecting…"
    t0=$SECONDS
    cli disconnect >/dev/null 2>&1 || true
    log_timing "disconnect secs=$((SECONDS - t0))"
    clear_pending
    clear_job
    notify "Disconnected"
    ;;
  best)
    track_job
    set_pending best best "Best location"
    notify "Connecting…" "Best location"
    if do_connect best; then
      clear_pending
      clear_job
      notify "Connected" "Best location"
    else
      clear_pending
      clear_job
      notify "Failed" "Best location"
      exit 1
    fi
    ;;
  connect)
    loc="${2:-}"
    [[ -n "$loc" ]] || exit 1
    track_job
    set_pending connect "$loc" "$loc"
    notify "Connecting…" "$loc"
    if do_connect "$loc"; then
      clear_pending
      clear_job
      notify "Connected" "$loc"
    else
      clear_pending
      clear_job
      notify "Failed" "$loc"
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 status|pending|cancel|locations|pings|ping-refresh|favs|fav-toggle <city>|disconnect|best|connect <location>" >&2
    exit 2
    ;;
esac
