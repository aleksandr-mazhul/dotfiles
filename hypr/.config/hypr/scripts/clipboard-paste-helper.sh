#!/usr/bin/env bash
# Restore focus to the original window, then paste.
# Avoid leaving temporary paste payloads as the "newest" clipboard history item.
set -euo pipefail

PREV_ADDR_FILE="/tmp/hypr-clipboard-prev-addr"

restore_focus() {
  if [[ -f "$PREV_ADDR_FILE" ]]; then
    addr="$(tr -d '[:space:]' <"$PREV_ADDR_FILE")"
    if [[ -n "$addr" ]]; then
      hyprctl dispatch focuswindow "address:$addr" >/dev/null || true
    fi
  fi
}

paste_key() {
  if command -v wtype >/dev/null; then
    wtype -M ctrl -k v -m ctrl
  fi
}

# Drop internal helper entries so real copies stay on top
scrub_paste_artifacts() {
  command -v cliphist >/dev/null || return 0
  cliphist list 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *hypr-clipboard-paste*|*"file:///tmp/hypr-clipboard"*)
        printf '%s\n' "$line" | cliphist delete 2>/dev/null || true
        ;;
    esac
  done
}

restore_focus
sleep 0.06

mode="${1:-}"
case "$mode" in
  uri)
    payload_path="${2:?}"
    wl-copy -t text/uri-list <"$payload_path"
    paste_key
    sleep 0.15
    scrub_paste_artifacts
    rm -f "$payload_path"
    ;;
  seq)
    blob="${2:?}"
    meta="${3:?}"
    # Keep last pasted payload for optional re-copy as newest real item
    last_chunk_file="$(mktemp)"
    last_mime_file="$(mktemp)"
    python3 - "$blob" "$meta" "$last_chunk_file" "$last_mime_file" <<'PY'
import sys, subprocess, time
from pathlib import Path
blob, meta, last_chunk, last_mime = map(Path, sys.argv[1:5])
mimes = meta.read_text().splitlines()
data = blob.read_bytes()
i = 0
idx = 0
last = b""
last_m = "text/plain"
while i + 4 <= len(data):
    n = int.from_bytes(data[i:i+4], "big"); i += 4
    chunk = data[i:i+n]; i += n
    mime = mimes[idx] if idx < len(mimes) else "text/plain"
    idx += 1
    last, last_m = chunk, mime
    subprocess.run(["wl-copy", "-t", mime], input=chunk, check=False)
    subprocess.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"], check=False)
    time.sleep(0.12)
last_chunk.write_bytes(last)
last_mime.write_text(last_m)
blob.unlink(missing_ok=True)
meta.unlink(missing_ok=True)
PY
    sleep 0.1
    scrub_paste_artifacts
    # Re-store last pasted content so it remains the newest history entry
    if [[ -s "$last_chunk_file" ]]; then
      mime="$(cat "$last_mime_file" 2>/dev/null || echo text/plain)"
      wl-copy -t "$mime" <"$last_chunk_file"
      cliphist store <"$last_chunk_file" 2>/dev/null || true
    fi
    rm -f "$last_chunk_file" "$last_mime_file"
    ;;
  *)
    exit 1
    ;;
esac
