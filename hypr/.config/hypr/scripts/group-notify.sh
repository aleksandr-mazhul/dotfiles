#!/usr/bin/env bash
# Short OSD hint for group tab switches (hyprctl notify).
set -euo pipefail
prefix="${1:-}"
json="$(hyprctl -j activewindow 2>/dev/null || true)"
[[ -n "$json" ]] || exit 0
class="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("class") or "?")' <<<"$json")"
title="$(python3 -c 'import json,sys; print((json.load(sys.stdin).get("title") or "")[:48])' <<<"$json")"
msg="${prefix}${class}"
[[ -n "$title" ]] && msg+=" — ${title}"
hyprctl notify -1 1600 "rgb(ffb688)" "$msg" >/dev/null
