#!/usr/bin/env bash
# Mac-like volume control: 16 steps (0, ~6%, …, 100%), same grid as qs-brightness.sh.
# Usage: qs-volume.sh get|up|down|mute
set -euo pipefail

cmd="${1:-}"
SINK="@DEFAULT_AUDIO_SINK@"

clamp() {
    local n="${1:-0}"
    (( n < 0 )) && n=0
    (( n > 100 )) && n=100
    echo "$n"
}

# PipeWire volume as integer percent 0–100.
# Prints nothing and returns 1 if the sink is missing / wpctl failed —
# callers must NOT treat that as 0% (that caused surprise volume drops).
get_pct() {
    local line vol
    line="$(wpctl get-volume "$SINK" 2>/dev/null || true)"
    # "Volume: 0.45" or "Volume: 0.45 [MUTED]"
    vol="$(printf '%s\n' "$line" | awk '/Volume:/{print $2; exit}')"
    if [[ -z "${vol:-}" ]]; then
        return 1
    fi
    awk -v v="$vol" 'BEGIN { printf "%d\n", int(v * 100.0 + 0.5) }'
}

set_pct() {
    local pct
    pct="$(clamp "${1:-0}")"
    # Absolute set; -l 1 caps at 100% (no soft-boost via keys).
    wpctl set-volume -l 1 "$SINK" "${pct}%" >/dev/null 2>&1 || true
    echo "$pct"
}

# macOS-style: 16 steps across the range (0, 6, 12, …, 100).
mac_snap() {
    local cur="$1" dir="$2"  # dir: +1 / -1
    local i
    cur="$(clamp "$cur")"
    i=$(( (cur * 16 + 50) / 100 ))
    (( i < 0 )) && i=0
    (( i > 16 )) && i=16
    if (( dir > 0 )); then
        (( i < 16 )) && i=$(( i + 1 ))
    else
        (( i > 0 )) && i=$(( i - 1 ))
    fi
    echo $(( (i * 100 + 8) / 16 ))
}

# Match brightness hold cadence (~11 Hz).
rate_ok() {
    local now last lock
    lock="${XDG_RUNTIME_DIR:-/tmp}/rice-volume-rate"
    now="$(date +%s%3N 2>/dev/null || echo 0)"
    last="$(cat "$lock" 2>/dev/null || echo 0)"
    if [[ "$now" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]] && (( now > 0 && now - last < 90 )); then
        return 1
    fi
    printf '%s\n' "$now" >"$lock" 2>/dev/null || true
    return 0
}

case "$cmd" in
    get)
        get_pct || echo "?"
        ;;
    up)
        rate_ok || { get_pct || true; exit 0; }
        cur="$(get_pct)" || exit 0
        # Unmute on raise (macOS behavior).
        wpctl set-mute "$SINK" 0 >/dev/null 2>&1 || true
        set_pct "$(mac_snap "$cur" 1)"
        ;;
    down)
        rate_ok || { get_pct || true; exit 0; }
        cur="$(get_pct)" || exit 0
        set_pct "$(mac_snap "$cur" -1)"
        ;;
    mute)
        wpctl set-mute "$SINK" toggle >/dev/null 2>&1 || true
        get_pct || true
        ;;
    *)
        echo "usage: $0 get|up|down|mute" >&2
        exit 2
        ;;
esac
