#!/usr/bin/env bash
# Brightness for rice QS / OSD / XF86 keys.
# 1) laptop backlight via brightnessctl
# 2) raw DDC via qs-brightness-ddc.py (works on nouveau where ddcutil refuses buses)
# 3) ddcutil fallback
#
# Usage: qs-brightness.sh get|cache|max|set <0-100>|up [n]|down [n]
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
    ( printf '%s\n' "$pct" >"$CACHE_FILE" ) 2>/dev/null || true
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

set_pct() {
    local pct out
    pct="$(clamp "${1:-0}")"
    if have_backlight && command -v brightnessctl >/dev/null 2>&1; then
        bl_set_pct "$pct"
        out="$pct"
    elif out="$(raw_set "$pct")" && [[ "$out" =~ ^[0-9]+$ ]]; then
        pct="$(clamp "$out")"
    elif command -v ddcutil >/dev/null 2>&1 && ddcutil_set "$pct"; then
        out="$pct"
    else
        echo "qs-brightness: no working backend" >&2
        write_cache "$pct"
        echo "$pct"
        return 1
    fi
    write_cache "$pct"
    echo "$pct"
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
        set_pct "$(mac_snap "$(cache_get)" 1)"
        ;;
    down)
        rate_ok || { cache_get; exit 0; }
        set_pct "$(mac_snap "$(cache_get)" -1)"
        ;;
    *)
        echo "usage: $0 get|cache|max|list|target|set <n>|up|down" >&2
        exit 2
        ;;
esac
