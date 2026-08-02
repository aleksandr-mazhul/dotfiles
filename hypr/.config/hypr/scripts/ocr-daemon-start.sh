#!/usr/bin/env bash
# Start EasyOCR daemon if needed (keeps models in RAM).
# Default: defer ~25s after login so session paint stays snappy.
# Immediate: ocr-daemon-start.sh --now  (used by ocr-region fallback paths).
set -euo pipefail

OCR_PY="${HOME}/.local/share/screen-ocr/.venv/bin/python"
OCR_SCRIPT="${HOME}/.config/hypr/scripts/ocr-easyocr.py"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.sock"
LOG="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.log"
DELAY_SECS="${OCR_DEFER_SECS:-25}"

if [[ ! -x "$OCR_PY" ]]; then
  echo "EasyOCR venv missing" >&2
  exit 1
fi

# Already up?
if [[ -S "$SOCK" ]]; then
  exit 0
fi

# Session autostart: schedule and return immediately.
if [[ "${1:-}" != "--now" ]]; then
  (
    sleep "$DELAY_SECS"
    exec "$0" --now
  ) >/dev/null 2>&1 &
  disown
  exit 0
fi

rm -f "$SOCK"
nohup "$OCR_PY" "$OCR_SCRIPT" serve >"$LOG" 2>&1 &
disown

# Wait until socket appears / models loaded
for _ in $(seq 1 60); do
  if [[ -S "$SOCK" ]]; then
    # give reader a moment after bind
    sleep 0.2
    exit 0
  fi
  sleep 0.5
done

echo "OCR daemon failed to start; see $LOG" >&2
exit 1
