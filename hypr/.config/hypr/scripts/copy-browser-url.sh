#!/usr/bin/env bash
# Copy current tab URL from Chromium-based browsers (Yandex, Chrome, …).
set -euo pipefail

# Wait for Ctrl/Shift to be released so we don't chord into DevTools
sleep 0.12
wtype -M ctrl -k l -m ctrl
sleep 0.08
wtype -M ctrl -k a -m ctrl
sleep 0.05
wtype -M ctrl -k c -m ctrl
sleep 0.08
wtype -k Escape

notify-send -a "Yandex" -u low "URL скопирован" 2>/dev/null || true
