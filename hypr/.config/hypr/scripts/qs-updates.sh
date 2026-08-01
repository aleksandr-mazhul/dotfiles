#!/usr/bin/env bash
# Package update helpers for Quick Settings
set -uo pipefail

cmd="${1:-}"

pac_count() {
  local n
  n="$(checkupdates 2>/dev/null | wc -l | tr -d '[:space:]')"
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  printf '%s' "$n"
}

aur_count() {
  local n
  n="$(yay -Qua 2>/dev/null | wc -l | tr -d '[:space:]')"
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  printf '%s' "$n"
}

case "$cmd" in
  count)
    p="$(pac_count)"
    a="$(aur_count)"
    echo "$((p + a))"
    echo "pac=${p}"
    echo "aur=${a}"
    ;;
  list)
    # kind|name|detail
    checkupdates 2>/dev/null | while read -r name old arrow new rest; do
      [[ -n "${name:-}" ]] || continue
      echo "pac|${name}|${old:-?} → ${new:-?}"
    done || true
    yay -Qua 2>/dev/null | while read -r name old arrow new rest; do
      [[ -n "${name:-}" ]] || continue
      echo "aur|${name}|${old:-?} → ${new:-?}"
    done || true
    ;;
  *)
    echo "usage: $0 count|list" >&2
    exit 2
    ;;
esac
