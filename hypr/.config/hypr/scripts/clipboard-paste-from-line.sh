#!/usr/bin/env bash
# Paste a cliphist list-line into the previously focused window.
set -euo pipefail

list_line="${1:-}"
prev_addr="${2:-}"
[[ -n "$list_line" ]] || exit 1

PREV_ADDR_FILE="/tmp/hypr-clipboard-prev-addr"
if [[ -n "$prev_addr" ]]; then
  printf '%s\n' "$prev_addr" >"$PREV_ADDR_FILE"
fi

HELPER="$(dirname "$0")/clipboard-paste-helper.sh"
TMP_DIR="${TMPDIR:-/tmp}/hypr-clipboard-paste"
mkdir -p "$TMP_DIR"

payload="$(mktemp)"
cleanup() { rm -f "$payload"; }
trap cleanup EXIT

printf '%s\n' "$list_line" | cliphist decode >"$payload"
[[ -s "$payload" ]] || exit 1

if printf '%s' "$list_line" | rg -qi '\[\[\s*binary data|image/'; then
  ext="png"
  if printf '%s' "$list_line" | rg -qi 'jpe?g'; then
    ext="jpg"
  elif printf '%s' "$list_line" | rg -qi 'webp'; then
    ext="webp"
  elif printf '%s' "$list_line" | rg -qi 'gif'; then
    ext="gif"
  fi
  img="$TMP_DIR/clip-1.$ext"
  cp -f "$payload" "$img"
  uri_file="${TMPDIR:-/tmp}/hypr-clipboard-uri.txt"
  python3 - "$img" "$uri_file" <<'PY'
import pathlib, sys
img, out = map(pathlib.Path, sys.argv[1:3])
out.write_text(img.resolve().as_uri() + "\n")
PY
  exec bash "$HELPER" uri "$uri_file"
fi

blob="${TMPDIR:-/tmp}/hypr-clipboard-seq.bin"
meta="${TMPDIR:-/tmp}/hypr-clipboard-seq.meta"
python3 - "$payload" "$blob" "$meta" <<'PY'
import sys
from pathlib import Path
payload, blob, meta = map(Path, sys.argv[1:4])
data = payload.read_bytes()
blob.write_bytes(len(data).to_bytes(4, "big") + data)
meta.write_text("text/plain\n")
PY
exec bash "$HELPER" seq "$blob" "$meta"
