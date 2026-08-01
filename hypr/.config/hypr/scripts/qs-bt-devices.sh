#!/usr/bin/env bash
# List Bluetooth devices for Quick Settings.
# Output lines: mac|name|paired|connected
set -euo pipefail

# Brief discovery so nearby devices show up (paired alone is often empty).
timeout 5 bluetoothctl --timeout 4 scan on >/dev/null 2>&1 || true
bluetoothctl scan off >/dev/null 2>&1 || true

paired_macs="$(bluetoothctl devices Paired 2>/dev/null | awk '/^Device /{print toupper($2)}' || true)"
connected_macs="$(bluetoothctl devices Connected 2>/dev/null | awk '/^Device /{print toupper($2)}' || true)"

is_in() {
  local needle="$1" hay="$2"
  printf '%s\n' "$hay" | grep -qxF "$needle"
}

bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
  [[ -n "${mac:-}" ]] || continue
  [[ -n "${name:-}" ]] || name="$mac"
  umac="$(printf '%s' "$mac" | tr '[:lower:]' '[:upper:]')"
  paired=0
  connected=0
  if is_in "$umac" "$paired_macs"; then paired=1; fi
  if is_in "$umac" "$connected_macs"; then connected=1; fi
  # Prefer named devices; still show MAC-only as last resort
  printf '%s|%s|%s|%s\n' "$mac" "$name" "$paired" "$connected"
done
