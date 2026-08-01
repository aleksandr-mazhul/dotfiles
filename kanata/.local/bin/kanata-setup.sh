#!/usr/bin/env bash
# One-shot host setup for kanata (uinput + input group).
# Safe to re-run. Needs sudo.
set -euo pipefail

ASKPASS="${SUDO_ASKPASS:-$HOME/.local/bin/sudo-askpass-gtk.py}"
if [[ -x "$ASKPASS" ]]; then
  export SUDO_ASKPASS="$ASKPASS"
  SUDO=(sudo -A)
else
  SUDO=(sudo)
fi

echo "==> Load uinput"
"${SUDO[@]}" modprobe uinput
echo uinput | "${SUDO[@]}" tee /etc/modules-load.d/uinput.conf >/dev/null

echo "==> udev rule for /dev/uinput"
"${SUDO[@]}" tee /etc/udev/rules.d/99-uinput.rules >/dev/null <<'EOF'
KERNEL=="uinput", MODE="0660", GROUP="input", OPTIONS+="static_node=uinput"
EOF
"${SUDO[@]}" udevadm control --reload-rules
"${SUDO[@]}" udevadm trigger --name-match=uinput

echo "==> Add $USER to input group"
"${SUDO[@]}" usermod -aG input "$USER"

echo
echo "Done."
echo "  /dev/uinput: $(ls -l /dev/uinput 2>/dev/null || echo MISSING)"
echo "  groups now:  $(id -nG)   (input may appear only after re-login)"
echo
echo "Re-login (or reboot) so the input group applies to your graphical session, then:"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now kanata.service"
echo "  systemctl --user status kanata.service"
echo
echo "Quick test without re-login:"
echo "  Caps Lock tap = Esc, hold = Ctrl  (a live kanata may already be running)"
