#!/usr/bin/env bash
# Paste multiple cliphist list-lines sequentially into the previously focused window.
# Usage: clipboard-paste-batch.sh <prev-addr> <list-line> [list-line...]
set -euo pipefail

prev_addr="${1:-}"
shift || true
[[ $# -gt 0 ]] || exit 1

SCRIPT="$(dirname "$0")/clipboard-paste-from-line.sh"
for line in "$@"; do
  [[ -n "$line" ]] || continue
  bash "$SCRIPT" "$line" "$prev_addr" || true
  sleep 0.35
done
