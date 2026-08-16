#!/usr/bin/env bash
# Recover input / layout helpers after lock, sleep, or USB blips.
# Idle DPMS + autosuspend often drops wireless receivers; kanata then
# loses devices and Ergohaven layout sync goes stale.
set -uo pipefail

log() { printf '[session-unlock-repair] %s\n' "$*" >&2; }

# Avoid stampedes if lock/sleep/resume fire together.
LOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/session-unlock-repair.lock"
mkdir -p "$(dirname "$LOCK")"
exec 9>"$LOCK"
if ! flock -n 9; then
  log "already running"
  exit 0
fi

hyprctl dispatch dpms on >/dev/null 2>&1 || true

# Give USB receivers a moment to reappear after DPMS/sleep.
sleep 0.8

kanata_pid() { pgrep -x kanata | head -1; }

# True if kanata has the real device node open (EVIOCGRAB).
kanata_has_device() {
  local byid="$1" real pid
  [[ -e "$byid" ]] || return 1
  real="$(readlink -f "$byid" 2>/dev/null)" || return 1
  pid="$(kanata_pid)" || return 1
  ls -l "/proc/${pid}/fd" 2>/dev/null | grep -q -- "$real"
}

EXPECTED_KBDS=(
  /dev/input/by-id/usb-Ergohaven_K:03_v3_v4_vial:f64c2b3c-event-kbd
  /dev/input/by-id/usb-Compx_VGN_Dragonfly_4K_Receiver-event-kbd
)

need_kanata_restart=0
if ! systemctl --user is-active --quiet kanata.service || [[ -z "$(kanata_pid)" ]]; then
  need_kanata_restart=1
  log "kanata inactive"
else
  present=0
  grabbed=0
  for dev in "${EXPECTED_KBDS[@]}"; do
    [[ -e "$dev" ]] || continue
    present=$((present + 1))
    if kanata_has_device "$dev"; then
      grabbed=$((grabbed + 1))
    fi
  done

  if (( present > 0 && grabbed == 0 )); then
    # Alive but holding nothing — hard fail.
    need_kanata_restart=1
    log "kanata running but grabbed 0/${present} keyboards"
  elif (( present > grabbed )); then
    # Partial: give inotify watch a chance before restarting (restart kills HRM briefly).
    log "kanata partial grab ${grabbed}/${present} — waiting for device watch"
    for _ in $(seq 1 15); do
      sleep 0.2
      grabbed=0
      for dev in "${EXPECTED_KBDS[@]}"; do
        [[ -e "$dev" ]] || continue
        kanata_has_device "$dev" && grabbed=$((grabbed + 1))
      done
      (( grabbed >= present )) && break
    done
    if (( grabbed < present && grabbed == 0 )); then
      need_kanata_restart=1
      log "watch did not recover grabs — restarting"
    elif (( grabbed < present )); then
      log "still partial ${grabbed}/${present}, leaving kanata (watch may finish)"
    else
      log "watch recovered all grabs"
    fi
  else
    log "kanata grabs ok (${grabbed}/${present})"
  fi
fi

if (( need_kanata_restart )); then
  log "restarting kanata"
  systemctl --user restart kanata.service >/dev/null 2>&1 || true
  for _ in $(seq 1 40); do
    sleep 0.15
    for dev in "${EXPECTED_KBDS[@]}"; do
      kanata_has_device "$dev" && break 2
    done
  done
fi

# Disable USB autosuspend on keyboard/mouse HID interfaces (best-effort).
for ctrl in /sys/bus/usb/devices/*/power/control; do
  [[ -w "$ctrl" ]] || continue
  # Only touch devices that look like HID parents with product strings we care about.
  base="$(dirname "$(dirname "$ctrl")")"
  prod="$(tr -d '\n' <"$base/product" 2>/dev/null || true)"
  case "$prod" in
    *Ergohaven*|*Dragonfly*|*SEMICO*|*Gaming\ Keyboard*)
      echo on >"$ctrl" 2>/dev/null || true
      ;;
  esac
done

ensure_bg() {
  local pattern="$1"
  shift
  if pgrep -f "$pattern" >/dev/null 2>&1; then
    return 0
  fi
  log "starting: $*"
  "$@" >/dev/null 2>&1 &
  disown || true
}

# Layout / per-window EN-RU helpers (flock makes duplicate starts safe).
ensure_bg 'eh-layout-sync\.sh' "$HOME/.config/hypr/scripts/eh-layout-sync.sh"
ensure_bg 'eh-window-layout\.py' "$HOME/.config/hypr/scripts/eh-window-layout.py"

# Re-apply Vial default layer after the board re-enumerates.
"$HOME/.config/hypr/scripts/eh-default-layer.sh" >/dev/null 2>&1 &

# Rice / wallpaper / clipboard watchers — only if they vanished.
if ! pgrep -x quickshell >/dev/null 2>&1 && ! pgrep -f 'quickshell -c rice' >/dev/null 2>&1; then
  log "restarting quickshell rice"
  qs -c rice -n -d >/dev/null 2>&1 || true
fi
if ! pgrep -x swww-daemon >/dev/null 2>&1; then
  log "restarting swww-daemon"
  swww-daemon >/dev/null 2>&1 &
  disown || true
fi
if ! pgrep -f 'wl-paste --type text --watch cliphist' >/dev/null 2>&1; then
  log "restarting cliphist text watcher"
  wl-paste --type text --watch cliphist store >/dev/null 2>&1 &
  disown || true
fi
if ! pgrep -f 'wl-paste --type image --watch cliphist' >/dev/null 2>&1; then
  log "restarting cliphist image watcher"
  wl-paste --type image --watch cliphist store >/dev/null 2>&1 &
  disown || true
fi

log "done"
