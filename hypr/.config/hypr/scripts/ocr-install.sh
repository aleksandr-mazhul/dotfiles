#!/usr/bin/env bash
# Install user RapidOCR venv for Super+T (replaces the old EasyOCR stack).
set -euo pipefail

ROOT="${HOME}/.local/share/screen-ocr"
VENV="${ROOT}/.venv"
PY="${VENV}/bin/python"
SCRIPT="${HOME}/.config/hypr/scripts/ocr-daemon.py"
UV="${HOME}/.local/bin/uv"
force=0
[[ "${1:-}" == "--force" ]] && force=1

if [[ -x "$PY" && "$force" -eq 0 ]]; then
  if "$PY" -c "import rapidocr, onnxruntime" >/dev/null 2>&1; then
    echo "RapidOCR already installed in $VENV"
    exit 0
  fi
fi

if [[ -e "$ROOT" ]]; then
  if [[ ! -w "$ROOT" || ( -e "$VENV" && ! -w "$VENV" ) ]]; then
    echo "Replacing unwritable EasyOCR venv (needs sudo)…"
    sudo rm -rf "$ROOT"
  elif [[ "$force" -eq 1 && -d "$VENV" ]]; then
    rm -rf "$VENV"
  fi
fi

mkdir -p "$ROOT"

if [[ -x "$UV" ]]; then
  "$UV" venv --python 3.12 "$VENV"
  "$UV" pip install --python "$PY" "rapidocr>=3.4.0" onnxruntime
else
  python3 -m venv "$VENV"
  "$PY" -m pip install -U pip
  "$PY" -m pip install "rapidocr>=3.4.0" onnxruntime
fi

echo "Warming PP-OCRv5 models (first download)…"
"$PY" "$SCRIPT" warmup
echo "OCR venv ready: $VENV"
