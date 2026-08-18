#!/usr/bin/env bash
# Put a cliphist list-line on the system clipboard (no paste).
# Usage: clipboard-copy-from-line.sh <cliphist-list-line>
set -euo pipefail

list_line="${1:-}"
[[ -n "$list_line" ]] || exit 1

payload="$(mktemp)"
cleanup() { rm -f "$payload"; }
trap cleanup EXIT

printf '%s\n' "$list_line" | cliphist decode >"$payload"
[[ -s "$payload" ]] || exit 1

mime="text/plain"
if printf '%s' "$list_line" | rg -qi '\[\[\s*binary data|image/'; then
  mime="image/png"
  if printf '%s' "$list_line" | rg -qi 'jpe?g'; then
    mime="image/jpeg"
  elif printf '%s' "$list_line" | rg -qi 'webp'; then
    mime="image/webp"
  elif printf '%s' "$list_line" | rg -qi 'gif'; then
    mime="image/gif"
  fi
fi

wl-copy -t "$mime" <"$payload"
