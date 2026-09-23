#!/usr/bin/env bash
# Install the system-level (/etc) pieces of the rice. Idempotent; needs sudo.
#   ./system/install.sh
#
#   udev/rules.d/50-usb-hid-no-autosuspend.rules  receivers stay awake after DPMS
#   udev/rules.d/59-vial.rules                    Entropy/Vial hidraw access
#   udev/rules.d/70-intel-rapl.rules              CPU power readout for MangoHud
#   systemd/zram-generator.conf                   zram swap (ram / 2, zstd)
#   docker: socket-activated instead of started at boot (~4 s off graphical.target)
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

if systemctl list-unit-files docker.socket >/dev/null 2>&1 \
  && systemctl is-enabled -q docker.service 2>/dev/null; then
  "${SUDO[@]}" systemctl disable docker.service
  "${SUDO[@]}" systemctl enable docker.socket
  echo "docker: socket-activated (starts on first docker command)"
fi
echo "system: up to date"
