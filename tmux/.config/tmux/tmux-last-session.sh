#!/usr/bin/env bash
# Remember the tmux session the user was actually on.
# client-detached fires after the client is gone, so resurrect's
# #{client_session} is empty and the next boot would attach to whatever
# session was created last (Java, not DevOps).
set -uo pipefail

name="${1:-}"
case "$name" in
  ""|"#{hook_session_name}"|"#{session_name}") exit 0 ;;
esac
# Session names in this rice are single tokens (dev-ops, frontend, java).
case "$name" in
  *[!A-Za-z0-9._+-]*|"."|"..") exit 0 ;;
esac

file="${TMUX_LAST_SESSION_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux/last-session}"
mkdir -p "$(dirname "$file")"
tmp="${file}.tmp.$$"
printf '%s\n' "$name" >"$tmp"
mv -f "$tmp" "$file"
