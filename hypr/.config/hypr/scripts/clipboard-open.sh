#!/usr/bin/env bash
# Save the currently focused window, then open clipboard popup.
set -euo pipefail
export GDK_BACKEND=wayland

PREV_ADDR="/tmp/hypr-clipboard-prev-addr"
# Do not overwrite previous target with the clipboard window itself
if ! hyprctl activewindow -j 2>/dev/null | rg -q 'com.hypr.clipboardhistory'; then
  hyprctl activewindow -j 2>/dev/null \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("address",""))' \
    >"$PREV_ADDR" || true
fi

exec /usr/bin/python3 "$HOME/.config/hypr/scripts/clipboard-ui.py" "$@"
