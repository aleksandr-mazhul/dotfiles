#!/usr/bin/env bash
# Store text as a NEW clipboard + cliphist entry (mtime = now).
# Usage: clipboard-store-text.sh
# Reads UTF-8 text from stdin.
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:$HOME/.local/bin:$PATH"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat >"$tmp"

# Reject empty payloads
[[ -s "$tmp" ]] || exit 0

wl-copy <"$tmp"
cliphist store <"$tmp" 2>/dev/null || true
