#!/usr/bin/env bash
# Restore focus to the original window, then paste.
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

restore_focus
sleep 0.06

mode="${1:-}"
case "$mode" in
  uri)
    payload_path="${2:?}"
    wl-copy -t text/uri-list <"$payload_path"
    paste_key
    rm -f "$payload_path"
    ;;
  seq)
    blob="${2:?}"
    meta="${3:?}"
    python3 - "$blob" "$meta" <<'PY'
import sys, subprocess, time
from pathlib import Path
blob, meta = Path(sys.argv[1]), Path(sys.argv[2])
mimes = meta.read_text().splitlines()
data = blob.read_bytes()
i = 0
idx = 0
while i + 4 <= len(data):
    n = int.from_bytes(data[i:i+4], "big"); i += 4
    chunk = data[i:i+n]; i += n
    mime = mimes[idx] if idx < len(mimes) else "text/plain"
    idx += 1
    subprocess.run(["wl-copy", "-t", mime], input=chunk, check=False)
    subprocess.run(["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"], check=False)
    time.sleep(0.12)
blob.unlink(missing_ok=True)
meta.unlink(missing_ok=True)
PY
    ;;
  *)
    exit 1
    ;;
esac
