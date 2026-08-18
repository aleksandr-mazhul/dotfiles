#!/usr/bin/env bash
# Start RapidOCR daemon if needed (keeps models in RAM).
# Default: defer ~25s after login so session paint stays snappy.
# Immediate: ocr-daemon-start.sh --now  (used by ocr-region fallback paths).
set -euo pipefail

OCR_PY="${HOME}/.local/share/screen-ocr/.venv/bin/python"
OCR_SCRIPT="${HOME}/.config/hypr/scripts/ocr-daemon.py"
INSTALL="${HOME}/.config/hypr/scripts/ocr-install.sh"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-ocr.sock"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-ocr.pid"
LOG="${XDG_RUNTIME_DIR:-/tmp}/hypr-ocr.log"
OLD_SOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.sock"
OLD_PID="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.pid"
DELAY_SECS="${OCR_DEFER_SECS:-25}"

stop_pidfile() {
  local file="$1"
  if [[ -f "$file" ]]; then
    kill "$(cat "$file" 2>/dev/null)" 2>/dev/null || true
    rm -f "$file"
  fi
}

# Drop the old EasyOCR daemon so Super+T cannot hit the wrong engine.
stop_pidfile "$OLD_PID"
rm -f "$OLD_SOCK"
pkill -f "ocr-easyocr.py serve" 2>/dev/null || true

if [[ ! -x "$OCR_PY" ]] || ! "$OCR_PY" -c "import rapidocr" >/dev/null 2>&1; then
  if [[ "${1:-}" == "--now" && -x "$INSTALL" ]]; then
    "$INSTALL" || true
  fi
fi

if [[ ! -x "$OCR_PY" ]]; then
  echo "OCR venv missing" >&2
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

stop_pidfile "$PID_FILE"
pkill -f "ocr-daemon.py serve" 2>/dev/null || true
rm -f "$SOCK"
nohup "$OCR_PY" "$OCR_SCRIPT" serve >"$LOG" 2>&1 &
disown

for _ in $(seq 1 120); do
  if [[ -S "$SOCK" ]]; then
    sleep 0.2
    exit 0
  fi
  sleep 0.5
done

echo "OCR daemon failed to start; see $LOG" >&2
exit 1
