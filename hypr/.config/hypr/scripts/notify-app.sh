#!/usr/bin/env bash
# Unified notify helper: app icon + optional replace-id + fewer noisy toasts.
# Usage:
#   notify-app [--id ID] [--urgency low|normal|critical] [--time MS] [--transient]
#              <app-name> <icon> <summary> [body]
set -euo pipefail

replace_id=""
urgency="normal"
expire="3500"
transient=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) replace_id="$2"; shift 2 ;;
    --urgency) urgency="$2"; shift 2 ;;
    --time) expire="$2"; shift 2 ;;
    --transient) transient=1; shift ;;
    --) shift; break ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

app="${1:?app name}"
icon="${2:?icon}"
summary="${3:?summary}"
body="${4:-}"

args=(
  -a "$app"
  -i "$icon"
  -u "$urgency"
  -t "$expire"
  -h "string:desktop-entry:${app}"
)

# Prefer application icon slot when notify-send supports it
if notify-send --help 2>&1 | rg -q -- '--app-icon'; then
  args+=(-n "$icon")
fi

if [[ -n "$replace_id" ]]; then
  args+=(-r "$replace_id")
fi
if [[ "$transient" -eq 1 ]]; then
  args+=(-e)
fi

if [[ -n "$body" ]]; then
  notify-send "${args[@]}" -- "$summary" "$body"
else
  notify-send "${args[@]}" -- "$summary"
fi
