#!/usr/bin/env bash
# Select region → EasyOCR daemon (en+ru) → clipboard.
# Only one final notification (with icon); no spam while recognizing.
set -euo pipefail

OCR_PY="${HOME}/.local/share/screen-ocr/.venv/bin/python"
OCR_SCRIPT="${HOME}/.config/hypr/scripts/ocr-easyocr.py"
DAEMON_START="${HOME}/.config/hypr/scripts/ocr-daemon-start.sh"
NOTIFY="${HOME}/.config/hypr/scripts/notify-app.sh"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.sock"
# Stable replace id so OCR never stacks multiple toasts
OCR_NOTIFY_ID=424201

tmp="$(mktemp --suffix=.png)"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

if [[ ! -x "$OCR_PY" ]]; then
  "$NOTIFY" --id "$OCR_NOTIFY_ID" --urgency critical --time 4000 \
    OCR dialog-error "EasyOCR не установлен" "~/.local/share/screen-ocr"
  exit 1
fi

if ! geom="$(slurp 2>/dev/null)"; then
  exit 0
fi
[[ -z "${geom}" ]] && exit 0

grim -g "$geom" "$tmp"

if [[ ! -S "$SOCK" ]]; then
  # One replaceable status toast while model warms (first time in session)
  "$NOTIFY" --id "$OCR_NOTIFY_ID" --urgency low --time 5000 --transient \
    OCR dialog-information "OCR" "Загрузка модели…"
  "$DAEMON_START" --now || true
fi

text="$("$OCR_PY" "$OCR_SCRIPT" ocr "$tmp" 2>/tmp/ocr-easyocr.err || true)"
text="$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ -z "${text//[[:space:]]/}" ]]; then
  err="$(tr '\n' ' ' </tmp/ocr-easyocr.err 2>/dev/null | cut -c1-160 || true)"
  if [[ -n "$err" ]]; then
    "$NOTIFY" --id "$OCR_NOTIFY_ID" --urgency normal --time 3500 \
      OCR dialog-warning "OCR" "$err"
  else
    "$NOTIFY" --id "$OCR_NOTIFY_ID" --urgency low --time 2200 --transient \
      OCR dialog-information "Текст не найден"
  fi
  exit 0
fi

printf '%s' "$text" | wl-copy
if command -v cliphist >/dev/null; then
  printf '%s' "$text" | cliphist store 2>/dev/null || true
fi

preview="$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-120)"
"$NOTIFY" --id "$OCR_NOTIFY_ID" --urgency low --time 2800 --transient \
  OCR edit-copy "Скопировано" "$preview"
