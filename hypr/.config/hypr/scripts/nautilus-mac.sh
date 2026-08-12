#!/usr/bin/env bash
# Mac Finder–style actions for Nautilus (Cmd → Ctrl on this rice).
# Usage: nautilus-mac.sh <action>
set -euo pipefail

action="${1:-}"
lock="${XDG_RUNTIME_DIR:-/tmp}/nautilus-mac-wtype.lock"
if [[ -f "$lock" ]]; then
  exit 0
fi

if ! command -v wtype >/dev/null; then
  echo "wtype required" >&2
  exit 1
fi

trap 'rm -f "$lock"' EXIT
: >"$lock"
sleep 0.02

case "$action" in
  # Cmd+Backspace / Cmd+Delete → Move to Trash
  trash)
    wtype -k Delete
    ;;
  # Cmd+Option+Delete → Delete Immediately
  purge)
    wtype -M shift -k Delete -m shift
    ;;
  # Cmd+D → Duplicate (copy + paste in place)
  duplicate)
    wtype -M ctrl -k c -m ctrl
    sleep 0.05
    wtype -M ctrl -k v -m ctrl
    ;;
  # Cmd+Ctrl+T / keep bookmarks reachable (was Ctrl+D)
  bookmark)
    wtype -M ctrl -k d -m ctrl
    ;;
  # Cmd+↑ → enclosing folder
  up)
    wtype -M alt -k Up -m alt
    ;;
  # Cmd+↓ → open
  open)
    wtype -k Return
    ;;
  # Cmd+[ → back
  back)
    wtype -M alt -k Left -m alt
    ;;
  # Cmd+] → forward
  forward)
    wtype -M alt -k Right -m alt
    ;;
  # Cmd+Shift+G → go to folder
  goto)
    wtype -M ctrl -k l -m ctrl
    ;;
  # Cmd+I → Get Info
  info)
    wtype -M alt -k Return -m alt
    ;;
  # Quick Look–ish: open selection with default handler / loupe when image
  preview)
    # Nautilus has no Space-preview API; open via Enter then app — fallback: Ctrl+Return "Open With Default"
    wtype -M ctrl -k o -m ctrl
    ;;
  *)
    echo "usage: $0 trash|purge|duplicate|bookmark|up|open|back|forward|goto|info|preview" >&2
    exit 1
    ;;
esac
