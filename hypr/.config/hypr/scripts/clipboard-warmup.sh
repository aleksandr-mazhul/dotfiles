#!/usr/bin/env bash
# Prebuild clipboard index + image thumbs late in the session so Super+Q is instant.
# Default: defer ~12s after login (after kitty / zen / telegram / browser / cursor).
# Immediate: clipboard-warmup.sh --now
set -euo pipefail

INDEX="${HOME}/.config/hypr/scripts/clipboard-index.sh"
DELAY_SECS="${CLIPBOARD_WARMUP_SECS:-12}"

if [[ ! -f "$INDEX" ]]; then
  exit 0
fi

if [[ "${1:-}" != "--now" ]]; then
  (
    sleep "$DELAY_SECS"
    exec "$0" --now
  ) >/dev/null 2>&1 &
  disown
  exit 0
fi

nice_cmd=(nice -n 19)
if command -v ionice >/dev/null 2>&1; then
  nice_cmd=(nice -n 19 ionice -c 3)
fi

"${nice_cmd[@]}" bash "$INDEX" --warmup >/dev/null 2>&1 || true
