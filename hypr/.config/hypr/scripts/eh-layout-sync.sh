#!/usr/bin/env bash
# Sync Hyprland OS keyboard layout → Ergohaven firmware (Raw HID).
# Entropy Layout Sync is X11-only on Linux v0.3.1; this covers Wayland/Hyprland.
#
# Packet: [0xAC, layout_index, 0…]  (_LAYOUT from Ergohaven hid.c; EN=0, RU=1)
set -uo pipefail

LAYOUT_TYPE=172 # 0xAC
LOCK_FILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/eh-layout-sync.lock"
mkdir -p "$(dirname "$LOCK_FILE")"

# Single instance
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  exit 0
fi

log() { printf '[eh-layout-sync] %s\n' "$*" >&2; }

find_rawhid() {
  local d name
  for d in /sys/class/hidraw/hidraw*; do
    [[ -e "$d/device/uevent" ]] || continue
    name=$(sed -n 's/^HID_NAME=//p' "$d/device/uevent" 2>/dev/null || true)
    [[ "$name" == *Ergohaven* ]] || continue
    # QMK Raw HID descriptor: Usage Page 0xFF60, Usage 0x61
    if xxd -p -l 6 "$d/device/report_descriptor" 2>/dev/null | grep -qi '^0660ff0961'; then
      echo "/dev/$(basename "$d")"
      return 0
    fi
  done
  return 1
}

layout_index() {
  local name="${1,,}"
  case "$name" in
    *russian*|*русск*|ru|ru,*) echo 1 ;;
    *) echo 0 ;;
  esac
}

send_layout() {
  local idx="$1" dev
  dev=$(find_rawhid) || {
    log "no Ergohaven raw HID yet"
    return 1
  }
  python3 - "$dev" "$LAYOUT_TYPE" "$idx" <<'PY'
import os, sys
dev, typ, idx = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pkt = bytes([typ, idx] + [0] * 30)
fd = os.open(dev, os.O_RDWR)
try:
    os.write(fd, pkt)
finally:
    os.close(fd)
PY
  log "sent layout=$idx → $dev"
}

current_layout_name() {
  hyprctl -j devices 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
keyboards = d.get("keyboards") or []
main = next((k for k in keyboards if k.get("main")), None)
kb = main or (keyboards[0] if keyboards else None)
if not kb:
    sys.exit(1)
print(kb.get("active_keymap") or "")
'
}

sync_once() {
  local name idx
  name=$(current_layout_name) || return 1
  [[ -n "$name" ]] || return 1
  idx=$(layout_index "$name")
  send_layout "$idx"
}

for _ in $(seq 1 30); do
  sync_once && break
  sleep 1
done

sock="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
if [[ ! -S "$sock" ]]; then
  log "Hyprland socket missing: $sock"
  exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
  log "socat required (pacman -S socat)"
  exit 1
fi

log "watching $sock"
socat -u UNIX-CONNECT:"$sock" - 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    activelayout\>\>*)
      layout_part="${line#activelayout>>*,}"
      send_layout "$(layout_index "$layout_part")" || true
      ;;
  esac
done
