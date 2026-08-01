#!/usr/bin/env bash
# Persist and restore the last focused Hyprland workspace across reboots.
# Usage:
#   workspace-persist.sh watch    # restore once, then save on workspace changes
#   workspace-persist.sh restore  # restore only
#   workspace-persist.sh save     # save current once
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="${STATE_DIR}/last-workspace"
mkdir -p "$STATE_DIR"

# Hyprland 0.56 Lua config: classic `hyprctl dispatch workspace N` is invalid.
focus_workspace() {
  local id="$1"
  hyprctl eval "hl.dispatch(hl.dsp.focus({workspace=${id}}))" >/dev/null 2>&1 || true
}

current_id() {
  hyprctl -j activeworkspace 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true
}

save_current() {
  local id
  id="$(current_id)"
  # Only persist normal numbered workspaces (1–10 in this rice).
  if [[ "$id" =~ ^(10|[1-9])$ ]]; then
    printf '%s\n' "$id" >"$STATE_FILE"
  fi
}

restore_saved() {
  [[ -r "$STATE_FILE" ]] || return 0
  local id
  id="$(<"$STATE_FILE")"
  [[ "$id" =~ ^(10|[1-9])$ ]] || return 0
  # Let monitors / rename / silent autostart settle first.
  sleep 1.2
  focus_workspace "$id"
}

watch_and_save() {
  if [[ "${WORKSPACE_PERSIST_NO_RESTORE:-0}" != "1" ]]; then
    restore_saved &
  fi

  local last=""
  if [[ -r "$STATE_FILE" ]]; then
    last="$(<"$STATE_FILE")"
  fi

  while true; do
    local id
    id="$(current_id)"
    if [[ "$id" =~ ^(10|[1-9])$ && "$id" != "$last" ]]; then
      printf '%s\n' "$id" >"$STATE_FILE"
      last="$id"
    fi
    sleep 0.8
  done
}

case "${1:-watch}" in
  save) save_current ;;
  restore) restore_saved ;;
  watch) watch_and_save ;;
  *)
    echo "usage: $0 {watch|restore|save}" >&2
    exit 2
    ;;
esac
