#!/usr/bin/env bash
# Install Entropy v2 Vial hidraw udev rules. Run with: sudo ~/.config/hypr/scripts/entropy-install-udev.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/59-vial.rules"
DEST=/etc/udev/rules.d/59-vial.rules

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Need root. Run: sudo $0" >&2
  exit 1
fi

[[ -f "$SRC" ]] || { echo "missing $SRC" >&2; exit 1; }
install -m 644 "$SRC" "$DEST"
udevadm control --reload-rules
udevadm trigger --subsystem-match=hidraw
echo "OK: $DEST"
cat "$DEST"
echo
echo "Replug the keyboard, then start Entropy again."
