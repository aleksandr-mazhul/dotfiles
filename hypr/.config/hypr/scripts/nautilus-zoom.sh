#!/usr/bin/env bash
# Nautilus icon zoom via native shortcuts (immediate) + persist default level.
set -euo pipefail

dir="${1:-}"
lock="${XDG_RUNTIME_DIR:-/tmp}/nautilus-zoom-wtype.lock"
if [[ -f "$lock" ]]; then
  exit 0
fi

case "$dir" in
  in|up|+) gdir=in ;;
  out|down|-) gdir=out ;;
  reset|0) gdir=reset ;;
  *) echo "usage: $0 in|out|reset" >&2; exit 1 ;;
esac

# Persist for new windows/tabs
schema_icon="org.gnome.nautilus.icon-view"
schema_list="org.gnome.nautilus.list-view"
levels=(small small-plus medium large extra-large)
cur=$(gsettings get "$schema_icon" default-zoom-level 2>/dev/null | tr -d "'") || cur=medium
idx=2
for i in "${!levels[@]}"; do
  [[ "${levels[$i]}" == "$cur" ]] && idx=$i && break
done
case "$gdir" in
  in) idx=$((idx + 1)); ((idx >= ${#levels[@]})) && idx=$((${#levels[@]} - 1)) ;;
  out) idx=$((idx - 1)); ((idx < 0)) && idx=0 ;;
  reset) idx=2 ;;
esac
next="${levels[$idx]}"
gsettings set "$schema_icon" default-zoom-level "$next"
gsettings set "$schema_list" default-zoom-level "$next" 2>/dev/null || true

# Immediate zoom in the focused Nautilus view (lock avoids re-entry on Ctrl+- bind)
if command -v wtype >/dev/null; then
  trap 'rm -f "$lock"' EXIT
  : >"$lock"
  sleep 0.03
  case "$gdir" in
    in) wtype -M ctrl -k plus -m ctrl ;;
    out) wtype -M ctrl -k minus -m ctrl ;;
    reset) wtype -M ctrl -k 0 -m ctrl ;;
  esac
fi
