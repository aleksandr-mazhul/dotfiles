#!/usr/bin/env bash
# Session startup: daily apps (VPN is handled by vpn-autostart.sh — starts earlier).
set -uo pipefail

# Let the compositor settle before spawning windows
sleep 0.5
Telegram >/dev/null 2>&1 &
cursor >/dev/null 2>&1 &
kitty >/dev/null 2>&1 &
