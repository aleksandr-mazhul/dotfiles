#!/usr/bin/env bash
# Switch Zoom client tabs (Meeting ↔ shared screen, etc.)
# Usage: zoom-tab.sh next|prev
set -euo pipefail

action="${1:-next}"
lock="${XDG_RUNTIME_DIR:-/tmp}/zoom-tab-wtype.lock"
# Prevent re-entry when we re-inject Ctrl+Tab via wtype
if [[ -f "$lock" ]]; then
  exit 0
fi
trap 'rm -f "$lock"' EXIT
: >"$lock"

sleep 0.05
case "$action" in
  next)
    wtype -M ctrl -k Tab -m ctrl
    ;;
  prev)
    wtype -M ctrl -M shift -k Tab -m shift -m ctrl
    ;;
  *)
    echo "Usage: $0 next|prev" >&2
    exit 2
    ;;
esac
