#!/usr/bin/env bash
# Force English OS layout while the rice launcher is open; restore on close.
# eh-layout-sync watches Hyprland activelayout and keeps Ergohaven firmware aligned,
# so this does not reintroduce OS↔keyboard desync.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rice-launcher-kb-layout"

main_index() {
  hyprctl -j devices | python3 -c '
import json, sys
d = json.load(sys.stdin)
keyboards = d.get("keyboards") or []
main = next((k for k in keyboards if k.get("main")), None)
kb = main or (keyboards[0] if keyboards else None)
if not kb:
    print(0)
    raise SystemExit(0)
name = (kb.get("active_keymap") or "").lower()
print(1 if ("russian" in name or "русск" in name or name == "ru") else 0)
'
}

set_all() {
  local idx="$1"
  hyprctl -j devices | python3 -c '
import json, subprocess, sys
idx = sys.argv[1]
d = json.load(sys.stdin)
for kb in d.get("keyboards") or []:
    name = kb.get("name")
    if not name:
        continue
    # Skip pure consumer/system control nodes — switchxkblayout is for real keyboards.
    low = name.lower()
    if "consumer-control" in low or "system-control" in low:
        continue
    subprocess.run(
        ["hyprctl", "switchxkblayout", name, idx],
        check=False,
        capture_output=True,
    )
' "$idx"
}

case "${1:-}" in
  open)
    main_index >"$STATE"
    set_all 0
    ;;
  close)
    if [[ -f "$STATE" ]]; then
      idx="$(cat "$STATE" 2>/dev/null || echo 0)"
      rm -f "$STATE"
      case "$idx" in
        0|1) set_all "$idx" ;;
        *) set_all 0 ;;
      esac
    fi
    ;;
  *)
    echo "usage: $0 open|close" >&2
    exit 2
    ;;
esac
