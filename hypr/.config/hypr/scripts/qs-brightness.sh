#!/usr/bin/env bash
# Brightness for rice QS / OSD / XF86 keys.
# 1) laptop backlight via brightnessctl
# 2) raw DDC via qs-brightness-ddc.py (works on nouveau where ddcutil refuses buses)
# 3) ddcutil fallback
#
# Usage: qs-brightness.sh get|cache|max|set <0-100>|up [n]|down [n]
#
# set/up/down update the cache and the OSD at once, then ONE background applier
# pushes the latest value over DDC (~220 ms per verified write). Key repeat used
# to start a DDC write per press; they overlapped on the bus, lost steps and
# left the monitor out of sync with the OSD.
set +e
set -u

cmd="${1:-get}"
arg="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_DDC="${SCRIPT_DIR}/qs-brightness-ddc.py"

pick_cache_dir() {
    local d
    for d in \
        "${XDG_RUNTIME_DIR:-}/rice" \
        "${HOME}/.cache/rice" \
        "/tmp/rice-${USER:-user}"
    do
        [[ -z "$d" || "$d" == "/rice" ]] && continue
        mkdir -p "$d" 2>/dev/null || continue
        [[ -w "$d" ]] || continue
        printf '%s\n' "$d"
        return 0
    done
    printf '%s\n' "/tmp"
}

CACHE_DIR="$(pick_cache_dir)"
CACHE_FILE="${CACHE_DIR}/brightness.pct"

write_cache() {
    local pct="${1:-0}"
    # tmp + rename: readers never see a truncated file.
    ( printf '%s\n' "$pct" >"$CACHE_FILE.$$" && mv -f "$CACHE_FILE.$$" "$CACHE_FILE" ) 2>/dev/null || true
}

read_cache() {
    clamp "$(cat "$CACHE_FILE" 2>/dev/null || echo 0)"
}

notify_osd() {
    command -v qs >/dev/null 2>&1 || return 0
    ( qs -c rice ipc call brightness level "$1" >/dev/null 2>&1 & )
}

APPLY_LOCK="${CACHE_DIR}/brightness-apply.lock"
STEP_LOCK="${CACHE_DIR}/brightness-step.lock"

# Push the cached value to the hardware until it stops changing. Only one
# applier runs; presses during a write just move the cache ahead of it.
apply_loop() {
    exec 8>"$APPLY_LOCK"
    flock -n 8 || return 0
    local want got
    while :; do
        want="$(read_cache)"
        got="$(backend_set "$want")" || return 1
        [[ "$(read_cache)" == "$want" ]] || continue
        # Cache what the monitor reports, so system and monitor agree.
        if [[ "$got" =~ ^[0-9]+$ && "$got" != "$want" ]]; then
            write_cache "$got"
        fi
        return 0
    done
}

start_apply() {
    setsid -f "$0" __apply </dev/null >/dev/null 2>&1
}

have_backlight() {
    find /sys/class/backlight -mindepth 1 -maxdepth 1 -type d 2>/dev/null | grep -q .
}

clamp() {
    local n="${1:-0}"
    case "$n" in
        ''|*[!0-9-]*) n=0 ;;
    esac
    (( n < 0 )) && n=0
    (( n > 100 )) && n=100
    printf '%s\n' "$n"
}

bl_get_pct() {
    local cur max
    cur="$(brightnessctl -m get 2>/dev/null)"
    max="$(brightnessctl -m max 2>/dev/null)"
    [[ -z "${cur:-}" || -z "${max:-}" || "$max" -eq 0 ]] && { echo 0; return; }
    echo $(( (cur * 100 + max / 2) / max ))
}

bl_set_pct() {
    brightnessctl -e4 -n2 set "${1}%" >/dev/null 2>&1
}

raw_get() {
    python3 "$RAW_DDC" get 2>/dev/null
}

raw_set() {
    python3 "$RAW_DDC" set "$1" 2>/dev/null
}

raw_list() {
    python3 "$RAW_DDC" list 2>/dev/null
}

raw_target() {
    python3 "$RAW_DDC" target "$1" 2>/dev/null
}

ddcutil_get() {
    command -v ddcutil >/dev/null 2>&1 || return 1
    local line cur max
    line="$(ddcutil --sleep-multiplier=0.3 getvcp 10 --brief 2>/dev/null)" || return 1
    [[ -z "$line" ]] && return 1
    cur="$(awk '{for(i=1;i<=NF;i++) if($i=="C"&&i<NF){print $(i+1);exit}}' <<<"$line")"
    max="$(awk '{if(NF>=1&&$NF~/^[0-9]+$/)print $NF}' <<<"$line")"
    [[ -z "${cur:-}" || -z "${max:-}" || "$max" -eq 0 ]] && return 1
    echo $(( (cur * 100 + max / 2) / max ))
}

ddcutil_set() {
    local pct="$1" line max val
    pct="$(clamp "$pct")"
    line="$(ddcutil --sleep-multiplier=0.3 getvcp 10 --brief 2>/dev/null)"
    max="$(awk '{if(NF>=1&&$NF~/^[0-9]+$/)print $NF}' <<<"$line")"
    [[ -z "${max:-}" || "$max" -eq 0 ]] && max=100
    val=$(( (pct * max + 50) / 100 ))
    ddcutil --sleep-multiplier=0.3 setvcp 10 "$val" >/dev/null 2>&1
}

get_pct() {
    local pct=""
    if have_backlight && command -v brightnessctl >/dev/null 2>&1; then
        pct="$(bl_get_pct)"
    elif pct="$(raw_get)" && [[ "$pct" =~ ^[0-9]+$ ]]; then
        :
    elif pct="$(ddcutil_get)" && [[ "$pct" =~ ^[0-9]+$ ]]; then
        :
    elif [[ -f "$CACHE_FILE" ]]; then
        clamp "$(cat "$CACHE_FILE" 2>/dev/null || echo 0)"
        return
    else
        echo 0
        return
    fi
    pct="$(clamp "${pct:-0}")"
    write_cache "$pct"
    echo "$pct"
}

# Write to hardware only; print the value it ended up at.
backend_set() {
    local pct out
    pct="$(clamp "${1:-0}")"
    if have_backlight && command -v brightnessctl >/dev/null 2>&1; then
        bl_set_pct "$pct" && out="$pct"
    elif out="$(raw_set "$pct")" && [[ "$out" =~ ^[0-9]+$ ]]; then
        :
    elif command -v ddcutil >/dev/null 2>&1 && ddcutil_set "$pct"; then
        out="$pct"
    else
        echo "qs-brightness: no working backend" >&2
        return 1
    fi
    clamp "$out"
}

# Record the target and let the applier catch up. $2=osd shows the HUD (keys);
# the Quick Settings slider already shows its own level.
set_pct() {
    local pct
    pct="$(clamp "${1:-0}")"
    write_cache "$pct"
    [[ "${2:-}" == osd ]] && notify_osd "$pct"
    start_apply
    echo "$pct"
}

# One key step. The first press after a pause re-reads the monitor, so a change
# made with its own buttons is not stepped from a stale cache.
step() {
    local dir="$1" base age
    exec 7>"$STEP_LOCK"
    flock 7
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if (( age > 15 )) && flock -n "$APPLY_LOCK" true 2>/dev/null; then
        base="$(get_pct)"
    else
        base="$(read_cache)"
    fi
    set_pct "$(mac_snap "$base" "$dir")" osd
}

cache_get() {
    if [[ -f "$CACHE_FILE" ]]; then
        clamp "$(cat "$CACHE_FILE" 2>/dev/null || echo 0)"
    else
        get_pct
    fi
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

# Limit key-repeat to ~Mac cadence (~11 Hz) so holding feels smooth, not frantic.
rate_ok() {
    local now last lock
    lock="${XDG_RUNTIME_DIR:-/tmp}/rice-bright-rate"
    now="$(date +%s%3N 2>/dev/null || echo 0)"
    last="$(cat "$lock" 2>/dev/null || echo 0)"
    if [[ "$now" =~ ^[0-9]+$ && "$last" =~ ^[0-9]+$ ]] && (( now > 0 && now - last < 90 )); then
        return 1
    fi
    printf '%s\n' "$now" >"$lock" 2>/dev/null || true
    return 0
}

case "$cmd" in
    get)   get_pct ;;
    cache) cache_get ;;
    max)   echo 100 ;;
    list)  raw_list ;;
    target)
        [[ -n "${arg:-}" ]] || { echo "usage: $0 target all|<bus>" >&2; exit 2; }
        raw_target "$arg"
        ;;
    picture)
        # Restore comfortable contrast + natural color (sRGB/6500K), then brightness.
        mode="${arg:-realistic}"
        pct="${3:-65}"
        out="$(python3 "$RAW_DDC" picture "$mode" "$pct" 2>/dev/null)" || {
            echo "qs-brightness: picture failed" >&2
            exit 1
        }
        pct="$(clamp "${out:-65}")"
        write_cache "$pct"
        echo "$pct"
        ;;
    set)
        [[ -n "${arg:-}" ]] || { echo "usage: $0 set <0-100>" >&2; exit 2; }
        set_pct "$arg"
        ;;
    up)
        rate_ok || { cache_get; exit 0; }
        step 1
        ;;
    down)
        rate_ok || { cache_get; exit 0; }
        step -1
        ;;
    __apply) apply_loop ;;
    *)
        echo "usage: $0 get|cache|max|list|target|set <n>|up|down" >&2
        exit 2
        ;;
esac
