#!/usr/bin/env bash
# Reminder helper for Ergohaven/Vial default layer (PDF).
#
# QMK PDF(n) writes EEPROM only when that key is pressed. Host software cannot
# reliably set default_layer over stock VIA on all firmwares. If the board
# forgets PDF after reboot, put your daily layout on layer 0 in Vial instead.
#
# Optional marker file (stowed): ~/.config/ergohaven/default-layer
#   8      → expected default layer (documentation / future hooks)
#   off    → silence
set -uo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ergohaven/default-layer"
LAYER="${EH_DEFAULT_LAYER:-}"
[[ -z "$LAYER" && -f "$CFG" ]] && LAYER="$(tr -d '[:space:]' <"$CFG" || true)"
[[ -z "$LAYER" ]] && LAYER=8
case "${LAYER,,}" in
  off|no|false|disable|disabled) exit 0 ;;
esac

# Nothing to send over HID that is portable; keep a one-shot log for debugging.
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/ergohaven"
mkdir -p "$LOG_DIR"
printf '%s want_default_layer=%s\n' "$(date -Iseconds)" "$LAYER" >>"$LOG_DIR/default-layer.log"
exit 0
