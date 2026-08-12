#!/usr/bin/env bash
# Decode one cliphist list line to stdout (full text/bytes for clipboard preview).
# Usage: clipboard-decode-text.sh <cliphist-list-line>
set -euo pipefail
export PATH="/usr/local/bin:/usr/bin:$HOME/.local/bin:$PATH"

line="${1:-}"
[[ -n "$line" ]] || exit 1

# Cap decode size so huge blobs don't freeze the UI (~512 KiB text).
printf '%s\n' "$line" | cliphist decode | head -c 524288
