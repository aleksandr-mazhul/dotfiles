#!/usr/bin/env bash
# Select region → EasyOCR daemon (en+ru) → clipboard. Notify if empty.
set -euo pipefail

OCR_PY="${HOME}/.local/share/screen-ocr/.venv/bin/python"
OCR_SCRIPT="${HOME}/.config/hypr/scripts/ocr-easyocr.py"
DAEMON_START="${HOME}/.config/hypr/scripts/ocr-daemon-start.sh"
SOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-easyocr.sock"

tmp="$(mktemp --suffix=.png)"
cleanup() { rm -f "$tmp"; }
trap cleanup EXIT

if [[ ! -x "$OCR_PY" ]]; then
  notify-send -a OCR "OCR" "EasyOCR не установлен (~/.local/share/screen-ocr)" -u critical -t 4000
  exit 1
fi

# Cancel region selection quietly
if ! geom="$(slurp 2>/dev/null)"; then
  exit 0
fi
[[ -z "${geom}" ]] && exit 0

grim -g "$geom" "$tmp"

# Ensure warm daemon (first launch in session may take a bit)
if [[ ! -S "$SOCK" ]]; then
  notify-send -a OCR "OCR" "Загружаю модель (один раз за сессию)…" -u low -t 4000
  "$DAEMON_START" || true
fi

notify-send -a OCR "OCR" "Распознаю…" -u low -t 1200

text="$("$OCR_PY" "$OCR_SCRIPT" ocr "$tmp" 2>/tmp/ocr-easyocr.err || true)"
text="$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ -z "${text//[[:space:]]/}" ]]; then
  err="$(tr '\n' ' ' </tmp/ocr-easyocr.err 2>/dev/null | cut -c1-160 || true)"
  if [[ -n "$err" ]]; then
    notify-send -a OCR "OCR" "Ошибка: ${err}" -u normal -t 4000
  else
    notify-send -a OCR "OCR" "Текст не найден" -u low -t 2500
  fi
  exit 0
fi

printf '%s' "$text" | wl-copy
if command -v cliphist >/dev/null; then
  printf '%s' "$text" | cliphist store 2>/dev/null || true
fi

preview="$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-120)"
notify-send -a OCR "OCR" "Скопировано:\n${preview}" -u low -t 3000
