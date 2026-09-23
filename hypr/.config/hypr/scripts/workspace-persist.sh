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
  if [[ "$id" =~ ^([1-9]|1[0-6])$ ]]; then
    printf '%s\n' "$id" >"$STATE_FILE"
  fi
}

restore_saved() {
  [[ -r "$STATE_FILE" ]] || return 0
  local id
  id="$(<"$STATE_FILE")"
  [[ "$id" =~ ^([1-9]|1[0-6])$ ]] || return 0
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

  record() {
    if [[ "$1" =~ ^([1-9]|1[0-6])$ && "$1" != "$last" ]]; then
      printf '%s\n' "$1" >"$STATE_FILE"
      last="$1"
    fi
  }

  # Event-driven: workspacev2>>ID,NAME and focusedmonv2>>MON,ID from socket2
  # instead of polling hyprctl + jq every 0.8s. socat exits when Hyprland does;
  # the loop reconnects (or ends with the session once the socket is gone).
  local sock="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
  local line
  while [[ -S "$sock" ]]; do
    record "$(current_id)"
    while IFS= read -r line; do
      case "$line" in
        workspacev2\>\>*) line="${line#*>>}"; record "${line%%,*}" ;;
        focusedmonv2\>\>*) record "${line##*,}" ;;
      esac
    done < <(socat -U - "UNIX-CONNECT:$sock" 2>/dev/null)
    sleep 1
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
