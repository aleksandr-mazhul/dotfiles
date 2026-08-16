#!/usr/bin/env bash
# Session startup: daily apps (VPN is handled by vpn-autostart.sh — starts earlier).
# Stagger so qs/swww get the first seconds of the session.
set -uo pipefail

sleep 0.5
kitty >/dev/null 2>&1 &

(
  sleep 1.5
  zen-browser >/dev/null 2>&1 &
) &

(
  sleep 2
  # Wrapper forces 24h clocks (system en_US is 12h AM/PM).
  "$HOME/.local/bin/Telegram" >/dev/null 2>&1 &
) &

(
  sleep 3
  # Wrapper: Wayland + --disable-background-mode (no ghost weather toasts).
  "$HOME/.local/bin/yandex-browser-stable" >/dev/null 2>&1 &
) &

(
  sleep 4
  cursor >/dev/null 2>&1 &
) &
