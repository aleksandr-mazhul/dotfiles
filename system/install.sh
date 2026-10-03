#!/usr/bin/env bash
# Install the system-level (/etc) pieces of the rice. Idempotent; needs sudo.
#   ./system/install.sh
#
#   udev/rules.d/50-usb-hid-no-autosuspend.rules  receivers stay awake after DPMS
#   udev/rules.d/59-vial.rules                    Entropy/Vial hidraw access
#   udev/rules.d/70-intel-rapl.rules              CPU power readout for MangoHud
#   systemd/zram-generator.conf                   zram swap (ram / 2, zstd)
#   docker: socket-activated instead of started at boot (~4 s off graphical.target)
#   NetworkManager.service and bluetooth.service enabled when installed
#
# uinput/input group: kanata/.local/bin/kanata-setup.sh. i2c: bootstrap.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
SUDO=()
[[ "$(id -u)" -eq 0 ]] || SUDO=(sudo)

changed_udev=0
while IFS= read -r -d '' src; do
  rel="${src#"$ROOT"/}"
  dest="/$rel"
  if ! cmp -s "$src" "$dest"; then
    "${SUDO[@]}" install -D -m 644 "$src" "$dest"
    echo "installed $dest"
    [[ "$rel" == etc/udev/* ]] && changed_udev=1
  fi
done < <(find "$ROOT/etc" -type f -print0)

if [[ "$changed_udev" -eq 1 ]]; then
  "${SUDO[@]}" udevadm control --reload-rules
  "${SUDO[@]}" udevadm trigger --subsystem-match=usb --subsystem-match=hidraw --subsystem-match=powercap || true
fi

# zram-generator reads its config at boot; nothing to restart now.

# Socket activation: the daemon starts on the first docker command, not at
# boot. A fresh install leaves docker.service disabled, so "only if the
# service is already enabled" never reached the socket.
if systemctl cat docker.socket >/dev/null 2>&1; then
  if systemctl is-enabled -q docker.service 2>/dev/null; then
    "${SUDO[@]}" systemctl disable docker.service
  fi
  if ! systemctl is-enabled -q docker.socket 2>/dev/null; then
    "${SUDO[@]}" systemctl enable docker.socket
    echo "docker: socket-activated (starts on first docker command)"
  fi
fi

for unit in NetworkManager.service bluetooth.service; do
  systemctl cat "$unit" >/dev/null 2>&1 || continue
  if ! systemctl is-enabled -q "$unit" 2>/dev/null; then
    "${SUDO[@]}" systemctl enable "$unit"
    echo "enabled $unit"
  fi
done
echo "system: up to date"
