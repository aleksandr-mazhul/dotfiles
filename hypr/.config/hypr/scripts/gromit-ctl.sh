#!/usr/bin/env bash
# Ensure gromit-mpx daemon is running, then run a control command.
# Usage: gromit-ctl.sh toggle|clear|visibility|undo|redo|quit
set -euo pipefail

cmd="${1:-toggle}"
log="${XDG_CACHE_HOME:-$HOME/.cache}/gromit-ctl.log"

log_event() {
  local focus=""
  focus="$(hyprctl activewindow -j 2>/dev/null | python3 -c "
import json, sys
try:
    w = json.load(sys.stdin)
    print('%s\t%s' % (w.get('class', ''), (w.get('title') or '')[:80]))
except Exception:
    print('?\t?')
" 2>/dev/null || printf '?\t?')"
  mkdir -p "$(dirname "$log")"
  printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$cmd" "$focus" >>"$log"
}

if ! command -v gromit-mpx >/dev/null 2>&1; then
  notify-send -a Gromit "Gromit-MPX not installed" 2>/dev/null || true
  exit 1
fi

if ! pgrep -x gromit-mpx >/dev/null 2>&1; then
  # Ensure intro is off (also stowed as ~/.config/gromit-mpx.ini).
  ini="${XDG_CONFIG_HOME:-$HOME/.config}/gromit-mpx.ini"
  if [[ ! -f "$ini" ]]; then
    printf '%s\n' '[General]' 'ShowIntroOnStartup=false' '[Drawing]' 'Opacity=0.85' >"$ini"
  fi
  # opacity ~0.85 keeps UI readable under annotations
  gromit-mpx -o 0.85 >/dev/null 2>&1 &
  # give the daemon a moment before the client command
  sleep 0.35
fi

log_event

case "$cmd" in
  toggle|paint)
    gromit-mpx --toggle
    notify-send -a Gromit -u low "Draw mode" "Toggle paint (RMB=eraser, Shift=blue, Ctrl=yellow)" 2>/dev/null || true
    ;;
  clear)
    gromit-mpx --clear
    ;;
  visibility|hide)
    gromit-mpx --visibility
    ;;
  undo)
    gromit-mpx --undo
    ;;
  redo)
    gromit-mpx --redo
    ;;
  quit)
    gromit-mpx --quit || true
    ;;
  *)
    echo "Usage: $0 toggle|clear|visibility|undo|redo|quit" >&2
    exit 2
    ;;
esac
