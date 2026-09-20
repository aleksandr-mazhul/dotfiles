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
date +%s >"$RESTORING_FILE"
LOG="${STATE_DIR}/session-autostart.log"
# Do not unlink the restoring flag here: waypaper's theme script is async and
# would SIGUSR1 kitty after this script exits. session-apps.lua clears it.
{
  echo "=== $(date -Iseconds) pid=$$ ==="
} >>"$LOG"

launch_cmd() {
  local id="$1"
  case "$id" in
    kitty) printf '%s\n' /usr/bin/kitty ;;
    zen) printf '%s\n' zen-browser ;;
    firefox) printf '%s\n' firefox ;;
    yandex) printf '%s\n' "$HOME/.local/bin/yandex-browser-stable" ;;
    telegram) printf '%s\n' "$HOME/.local/bin/Telegram" ;;
    nautilus) printf '%s\n' "$HOME/.local/bin/nautilus-dark --new-window" ;;
    chatgpt) printf '%s\n' chatgpt ;;
    claude) printf '%s\n' claude-desktop ;;
    spotify) printf '%s\n' "spotify-launcher --skip-update" ;;
    obsidian) printf '%s\n' obsidian ;;
    code) printf '%s\n' code ;;
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
  local id="$1" ws="$2" skip_delay="${3:-}" cmd
  cmd="$(launch_cmd "$id")" || {
    echo "session-autostart: skip $id (no launch cmd)" >&2
    return 0
  }
  [[ "$ws" =~ ^([1-9]|1[0-6])$ ]] || return 0
  cmd_available "$cmd" || {
    echo "session-autostart: skip $id (missing $cmd)" >&2
    return 0
  }
  # Claude needs the VPN: launch detached, only after Windscribe is connected.
  if [[ "$id" == "claude" ]]; then
    echo "session-autostart: defer $id ws=$ws until VPN is up" >&2
    setsid -f "$HOME/.config/hypr/scripts/after-vpn-launch.sh" "$ws" "$cmd" >/dev/null 2>&1
    return 0
  fi
  # Theme reload SIGUSR1 races the first kitty; give wallpaper post_command time.
  if [[ "$id" == "kitty" && -z "$skip_delay" ]]; then
    sleep 2.5
  fi
  echo "session-autostart: spawn $id ws=$ws" >&2
  hyprctl eval "hl.exec_cmd([=[${cmd}]=], { workspace = [=[${ws} silent]=] })" >/dev/null 2>&1 || true
}

read_snapshot() {
  local line id ws side
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    side="A"
    if [[ "$line" =~ ^([a-z][a-z0-9_-]*)[[:space:]]+([0-9]+)[[:space:]]+([LRA])[[:space:]]*$ ]]; then
      id="${BASH_REMATCH[1]}"
      ws="${BASH_REMATCH[2]}"
      side="${BASH_REMATCH[3]}"
    elif [[ "$line" =~ ^([a-z][a-z0-9_-]*)[[:space:]]+([0-9]+)[[:space:]]*$ ]]; then
      id="${BASH_REMATCH[1]}"
      ws="${BASH_REMATCH[2]}"
    else
      continue
    fi
    # Claude always lives on C (2); Discord is never auto-started.
    [[ "$id" == "discord" ]] && continue
    [[ "$id" == "claude" ]] && ws=2
    printf '%s %s %s\n' "$id" "$ws" "$side"
  done
}

entries=()
if [[ -r "$STATE_FILE" ]]; then
  mapfile -t entries < <(read_snapshot <"$STATE_FILE")
fi

if ((${#entries[@]} == 0)); then
  if [[ -r "$STATE_FILE" ]]; then
    entries=("kitty 7 A")
  else
    entries=(
      "kitty 7 A"
      "zen 3 A"
      "telegram 9 A"
      "cursor 2 A"
    )
  fi
fi

# Claude is always autostarted (on C, after VPN) even if it was closed last session.
have_claude=0
for entry in "${entries[@]}"; do
  [[ "${entry%% *}" == "claude" ]] && have_claude=1
done
((have_claude)) || entries+=("claude 2 A")

extra=8
for entry in "${entries[@]}"; do
  case "${entry%% *}" in cursor) extra=25 ;; esac
done
{
  echo "entries=${#entries[@]} extra=$extra"
  printf '  %s\n' "${entries[@]}"
} >>"$LOG"

delay=0.4
# Group spawn by workspace: left/alone first, then preselect right on that workspace.
declare -A ws_has_right=()
for entry in "${entries[@]}"; do
  rest="${entry#* }"
  ws="${rest%% *}"
  side="${rest##* }"
  [[ "$side" == "R" ]] && ws_has_right["$ws"]=1
done

spawn_side() {
  local want="$1" entry id rest ws side
  for entry in "${entries[@]}"; do
    id="${entry%% *}"
    rest="${entry#* }"
    ws="${rest%% *}"
    side="${rest##* }"
    [[ "$side" == "$want" || ( "$want" == "LA" && "$side" != "R" ) ]] || continue
    (
      sleep "$delay"
      spawn "$id" "$ws"
    ) &
    delay="$(awk -v d="$delay" 'BEGIN { printf "%.1f", d + 0.35 }')"
  done
}

spawn_side LA

if ((${#ws_has_right[@]})); then
  sleep 1.2
  local_ws=""
  for local_ws in "${!ws_has_right[@]}"; do
    hyprctl dispatch focusworkspaceoncurrentmonitor "$local_ws" >/dev/null 2>&1 \
      || hyprctl dispatch workspace "$local_ws" >/dev/null 2>&1 || true
    hyprctl dispatch layoutmsg "preselect r" >/dev/null 2>&1 || true
  done
  spawn_side R
fi

# If a pair landed swapped, push the intended-left window left.
fix_sides() {
  python3 - "$STATE_FILE" <<'PY'
import json, subprocess, sys
from collections import defaultdict

path = sys.argv[1]
expected = defaultdict(dict)
try:
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) < 2 or parts[0].startswith("#"):
                continue
            app_id, ws = parts[0], parts[1]
            side = parts[2] if len(parts) > 2 else "A"
            if side in ("L", "R"):
                expected[ws][side] = app_id
except OSError:
    sys.exit(0)

if not expected:
    sys.exit(0)

raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
clients = json.loads(raw)
by_class = {}
for c in clients:
    cls = (c.get("class") or "").lower()
    ws = str((c.get("workspace") or {}).get("id") or "")
    at = c.get("at") or [0, 0]
    x = at[0] if isinstance(at, list) else 0
    by_class.setdefault((cls, ws), []).append((x, c.get("address")))

catalog = {
    "cursor": "cursor",
    "zen": ("zen", "zen-browser"),
    "code": ("code",),
    "kitty": ("kitty",),
    "nautilus": ("org.gnome.nautilus", "nautilus"),
    "telegram": ("org.telegram.desktop", "telegramdesktop"),
    "chatgpt": ("chatgpt",),
    "discord": ("discord",),
    "firefox": ("firefox",),
    "chrome": ("google-chrome", "google-chrome-stable", "chromium"),
    "claude": ("com.anthropic.claude",),
    "yandex": ("yandex-browser",),
    "webstorm": ("jetbrains-webstorm",),
    "clion": ("jetbrains-clion",),
    "obs": ("com.obsproject.studio", "obs"),
    "obsidian": ("obsidian",),
    "thunderbird": ("thunderbird",),
    "spotify": ("spotify",),
    "zoom": ("zoom",),
}

def class_windows(app_id, ws):
    out = []
    for cls in catalog.get(app_id, (app_id,)):
        out.extend(by_class.get((cls, ws), []))
    return out

for ws, sides in expected.items():
    left_id, right_id = sides.get("L"), sides.get("R")
    if not left_id or not right_id:
        continue
    lefts = class_windows(left_id, ws)
    rights = class_windows(right_id, ws)
    if not lefts or not rights:
        continue
    if left_id == right_id:
        windows = sorted(lefts)
        if len(windows) < 2:
            continue
        lx, laddr = windows[0]
        rx, raddr = windows[-1]
    else:
        lx, laddr = min(lefts)
        rx, raddr = min(rights)
    if lx <= rx:
        continue
    subprocess.run(["hyprctl", "dispatch", "focuswindow", f"address:{laddr}"], check=False)
    subprocess.run(["hyprctl", "dispatch", "movewindow", "l"], check=False)
PY
}

# Last spawn is issued at $delay-0.4; wait for windows to map before unfreezing.
# Cursor AppImage extract often exceeds 20s; keep the restoring flag until then.
sleep "$(awk -v d="$delay" -v e="$extra" 'BEGIN { printf "%.1f", d + e }')"
wait || true
fix_sides || true

# Kitty is often SIGUSR1'd by wallpaper theme on the first spawn. Retry per workspace.
count_kitty_on_ws() {
  local ws="$1"
  hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
ws = int(sys.argv[1])
clients = json.load(sys.stdin)
print(sum(1 for c in clients if (c.get("class") or "") == "kitty" and (c.get("workspace") or {}).get("id") == ws))
' "$ws" 2>/dev/null || echo 0
}

declare -A kitty_want_ws=()
for entry in "${entries[@]}"; do
  if [[ "${entry%% *}" == "kitty" ]]; then
    rest="${entry#* }"
    ws="${rest%% *}"
    kitty_want_ws["$ws"]=$(( ${kitty_want_ws[$ws]:-0} + 1 ))
  fi
done

retry_kitty() {
  local ws want live missing tries
  for ws in "${!kitty_want_ws[@]}"; do
    want="${kitty_want_ws[$ws]}"
    tries=0
    while ((tries < 3)); do
      live="$(count_kitty_on_ws "$ws")"
      live="${live:-0}"
      missing=$((want - live))
      ((missing > 0)) || break
      spawn kitty "$ws" skip
      sleep 0.8
      tries=$((tries + 1))
    done
  done
}

if ((${#kitty_want_ws[@]})); then
  retry_kitty
fi
