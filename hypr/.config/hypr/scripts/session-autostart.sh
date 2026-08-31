#!/usr/bin/env bash
# Restore last-session apps onto their saved workspaces.
# State: ~/.local/state/hypr/session-apps  (id workspace)
# Missing file → kitty/zen/telegram/cursor on home letters (no Yandex).
# Empty file  → kitty only, so login is never a blank desktop.
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/hypr"
STATE_FILE="${STATE_DIR}/session-apps"
RESTORING_FILE="${STATE_DIR}/session-apps.restoring"

mkdir -p "$STATE_DIR"
touch "$RESTORING_FILE"
cleanup() { rm -f "$RESTORING_FILE"; }
trap cleanup EXIT

launch_cmd() {
  local id="$1"
  case "$id" in
    kitty) printf '%s\n' kitty ;;
    zen) printf '%s\n' zen-browser ;;
    firefox) printf '%s\n' firefox ;;
    yandex) printf '%s\n' "$HOME/.local/bin/yandex-browser-stable" ;;
    telegram) printf '%s\n' "$HOME/.local/bin/Telegram" ;;
    nautilus) printf '%s\n' "$HOME/.local/bin/nautilus-dark --new-window" ;;
    chatgpt) printf '%s\n' chatgpt ;;
    claude) printf '%s\n' claude ;;
    discord) printf '%s\n' "$HOME/.local/bin/discord" ;;
    spotify) printf '%s\n' spotify ;;
    obsidian) printf '%s\n' obsidian ;;
    thunderbird) printf '%s\n' thunderbird ;;
    zoom) printf '%s\n' "$HOME/.config/hypr/scripts/zoom.sh" ;;
    obs) printf '%s\n' "obs --disable-shutdown-check" ;;
    webstorm) printf '%s\n' webstorm ;;
    clion) printf '%s\n' clion ;;
    chrome)
      local c
      for c in google-chrome-stable google-chrome chromium brave-browser; do
        if command -v "$c" >/dev/null 2>&1; then
          printf '%s\n' "$c"
          return 0
        fi
      done
      return 1
      ;;
    cursor)
      # Flush pending layout/theme/activity before first window (AppImage quit
      # otherwise overwrites vscdb patches). Prefer ~/.local/bin/cursor wrapper
      # (APPIMAGE_EXTRACT_AND_RUN) so in-app updates can replace the AppImage.
      if [[ -x "$HOME/.local/bin/vscode-cursor-sync" ]]; then
        "$HOME/.local/bin/vscode-cursor-sync" --apply-cursor-state >/dev/null 2>&1 || true
      fi
      if [[ -x "$HOME/.local/bin/cursor" ]]; then
        printf '%s\n' "$HOME/.local/bin/cursor"
      elif [[ -x "$HOME/applications/Cursor.AppImage" ]]; then
        # Never FUSE-mount: hl.exec_cmd is not a shell, so env= prefix won't work.
        # A tiny sh -c keeps EXTRACT_AND_RUN if the wrapper is missing.
        printf '%s\n' "sh -c 'APPIMAGE_EXTRACT_AND_RUN=1 exec \"\$HOME/applications/Cursor.AppImage\"'"
      else
        return 1
      fi
      ;;
    *) return 1 ;;
  esac
}

cmd_available() {
  local cmd="$1"
  local bin="${cmd%% *}"
  if [[ "$bin" == /* ]]; then
    [[ -x "$bin" ]]
  else
    command -v "$bin" >/dev/null 2>&1
  fi
}

spawn() {
  local id="$1" ws="$2" cmd
  cmd="$(launch_cmd "$id")" || return 0
  [[ "$ws" =~ ^([1-9]|1[0-6])$ ]] || return 0
  cmd_available "$cmd" || return 0
  # Lua long-brackets so paths with spaces stay one string.
  hyprctl eval "hl.exec_cmd([=[${cmd}]=], { workspace = [=[${ws} silent]=] })" >/dev/null 2>&1 || true
}

read_snapshot() {
  local line id ws
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^[a-z][a-z0-9_-]*[[:space:]]+[0-9]+$ ]] || continue
    id="${line%% *}"
    ws="${line##* }"
    printf '%s %s\n' "$id" "$ws"
  done
}

entries=()
if [[ -r "$STATE_FILE" ]]; then
  mapfile -t entries < <(read_snapshot <"$STATE_FILE")
fi

if ((${#entries[@]} == 0)); then
  if [[ -r "$STATE_FILE" ]]; then
    entries=("kitty 7")
  else
    entries=(
      "kitty 7"
      "zen 3"
      "telegram 9"
      "cursor 2"
    )
  fi
fi

extra=8
for entry in "${entries[@]}"; do
  case "${entry%% *}" in cursor) extra=25 ;; esac
done

delay=0.5
for entry in "${entries[@]}"; do
  id="${entry%% *}"
  ws="${entry##* }"
  (
    sleep "$delay"
    spawn "$id" "$ws"
  ) &
  delay="$(awk -v d="$delay" 'BEGIN { printf "%.1f", d + 0.5 }')"
done

# Last spawn is issued at $delay-0.5; wait for windows to map before unfreezing.
# Cursor AppImage extract often exceeds 20s; keep the restoring flag until then.
sleep "$(awk -v d="$delay" -v e="$extra" 'BEGIN { printf "%.1f", d + e }')"
wait || true
