#!/usr/bin/env bash
# Audit E1/E2/E4/A8: the exact bytes kitty.conf sends for tab switching, tab
# moving, and Shift+Enter, parsed live from kitty.conf so this test breaks if
# kitty.conf and the zellij binds drift apart.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

# t20_pane_id_at POS : the terminal pane id occupying tab position POS.
# Default tab names ("Tab #1", "Tab #2", ...) are derived from position, so
# they cannot detect a MoveTab swap; the underlying pane id can.
t20_pane_id_at() {
  local pos="$1"
  zj_panes_json | python3 -c '
import json, sys
pos = int(sys.argv[1])
for p in json.load(sys.stdin):
    if not p["is_plugin"] and p["tab_position"] == pos:
        print(p["id"]); break' "$pos"
}

# t20_kitty_hex NAME KEYS : kitty_map_hex or fail the test and return 1.
t20_kitty_hex() {
  local name="$1" keys="$2" hex
  if hex="$(kitty_map_hex "$keys")" && [ -n "$hex" ]; then
    printf '%s' "$hex"
  else
    t_fail "$name" "no 'map $keys send_text ...' line found in kitty.conf"
    return 1
  fi
}

if ! zj_start; then
  t_done
  exit
fi

# 3+ tabs so wrap-around is observable.
zj_keys_hex 02 63; sleep 0.3   # Ctrl+b c
zj_keys_hex 02 63; sleep 0.3   # Ctrl+b c
if [ "$(zj_tab_count)" -lt 3 ]; then
  t_fail "E1/E2 setup: 3 tabs exist" "only $(zj_tab_count)"
fi
zj_first_tab                  # start from tab 1 (position 0)

# --- E1: ctrl+page_up / ctrl+page_down step exactly one tab, with wrap ------

hex="$(t20_kitty_hex "ctrl+page_up bytes parsed from kitty.conf" ctrl+page_up)" || hex=""
if [ -n "$hex" ]; then
  pos_before="$(zj_tab_pos)"
  # shellcheck disable=SC2086 # hex is a space-separated list of byte pairs
  zj_keys_hex $hex
  sleep 0.3
  pos_after="$(zj_tab_pos)"
  n="$(zj_tab_count)"
  want=$(( (pos_before - 1 + n) % n ))
  assert_eq "E1 ctrl+page_up moves exactly one tab back (with wrap)" "$pos_after" "$want"
fi

hex="$(t20_kitty_hex "ctrl+page_down bytes parsed from kitty.conf" ctrl+page_down)" || hex=""
if [ -n "$hex" ]; then
  pos_before="$(zj_tab_pos)"
  # shellcheck disable=SC2086
  zj_keys_hex $hex
  sleep 0.3
  pos_after="$(zj_tab_pos)"
  n="$(zj_tab_count)"
  want=$(( (pos_before + 1) % n ))
  assert_eq "E1 ctrl+page_down moves exactly one tab forward (with wrap)" "$pos_after" "$want"
fi

# --- E1: ctrl+shift+[ / ctrl+shift+] are the same bytes, same effect -------

hex="$(t20_kitty_hex "ctrl+shift+[ bytes parsed from kitty.conf" "ctrl+shift+[")" || hex=""
if [ -n "$hex" ]; then
  pos_before="$(zj_tab_pos)"
  # shellcheck disable=SC2086
  zj_keys_hex $hex
  sleep 0.3
  n="$(zj_tab_count)"
  want=$(( (pos_before - 1 + n) % n ))
  assert_eq "E1 ctrl+shift+[ moves exactly one tab back (with wrap)" "$(zj_tab_pos)" "$want"
fi

hex="$(t20_kitty_hex "ctrl+shift+] bytes parsed from kitty.conf" "ctrl+shift+]")" || hex=""
if [ -n "$hex" ]; then
  pos_before="$(zj_tab_pos)"
  # shellcheck disable=SC2086
  zj_keys_hex $hex
  sleep 0.3
  n="$(zj_tab_count)"
  want=$(( (pos_before + 1) % n ))
  assert_eq "E1 ctrl+shift+] moves exactly one tab forward (with wrap)" "$(zj_tab_pos)" "$want"
fi

# --- E2: ctrl+shift+h / ctrl+shift+l move the active tab by one position --

zj_first_tab                  # back to tab 1 (position 0) for a clean base:
                                 # probe with the rightward move first (boundary-safe),
                                 # then move back, since default tab names are
                                 # position-derived and cannot show a swap by themselves.

hex_l="$(t20_kitty_hex "ctrl+shift+l bytes parsed from kitty.conf" ctrl+shift+l)" || hex_l=""
hex_h="$(t20_kitty_hex "ctrl+shift+h bytes parsed from kitty.conf" ctrl+shift+h)" || hex_h=""
if [ -n "$hex_l" ]; then
  id0_before="$(t20_pane_id_at 0)"
  id1_before="$(t20_pane_id_at 1)"
  # shellcheck disable=SC2086
  zj_keys_hex $hex_l
  sleep 0.3
  id0_mid="$(t20_pane_id_at 0)"
  id1_mid="$(t20_pane_id_at 1)"
  if [ "$id0_mid" = "$id1_before" ] && [ "$id1_mid" = "$id0_before" ]; then
    t_ok "E2 ctrl+shift+l moves the active tab one position right"
  else
    t_fail "E2 ctrl+shift+l moves the active tab one position right" "pos0 $id0_before->$id0_mid pos1 $id1_before->$id1_mid"
  fi

  if [ -n "$hex_h" ]; then
    # shellcheck disable=SC2086
    zj_keys_hex $hex_h
    sleep 0.3
    id0_back="$(t20_pane_id_at 0)"
    id1_back="$(t20_pane_id_at 1)"
    if [ "$id0_back" = "$id0_before" ] && [ "$id1_back" = "$id1_before" ]; then
      t_ok "E2 ctrl+shift+h moves the active tab one position back left"
    else
      t_fail "E2 ctrl+shift+h moves the active tab one position back left" "pos0=$id0_back pos1=$id1_back"
    fi
  fi
elif [ -n "$hex_h" ]; then
  t_skip "E2 ctrl+shift+h moves the active tab one position back left" "ctrl+shift+l probe unavailable"
fi

# --- E4/A8: Shift+Enter reaches the pane as CSI 13;2u, never a bare 0d ----

t20_write_reader() {
  cat >"$HOME/t20-kkp-reader.py" <<'PY'
import sys, os, termios, tty, select

fd = sys.stdin.fileno()
old = termios.tcgetattr(fd)
tty.setraw(fd)
try:
    if len(sys.argv) > 1 and sys.argv[1] == "kkp":
        os.write(fd, b"\x1b[>1u")
    buf = b""
    idle = 0
    while idle < 15:
        r, _, _ = select.select([fd], [], [], 0.1)
        if r:
            chunk = os.read(fd, 64)
            if not chunk:
                break
            buf += chunk
            idle = 0
        else:
            idle += 1
        if buf and idle > 3:
            break
    sys.stderr.write("T20HEX:" + buf.hex() + "\n")
finally:
    termios.tcsetattr(fd, termios.TCSADRAIN, old)
PY
}

hex="$(t20_kitty_hex "shift+enter bytes parsed from kitty.conf" shift+enter)" || hex=""
if [ -n "$hex" ]; then
  t20_write_reader
  zj_first_tab                  # a plain shell pane on tab 1
  zj_type 'python3 ~/t20-kkp-reader.py kkp'; zj_enter
  sleep 0.5
  # shellcheck disable=SC2086
  zj_keys_hex $hex
  sleep 1.0
  out="$(zj_pane_screen)"
  assert_contains "E4/A8 Shift+Enter reaches the pane as CSI 13;2u (protocol enabled)" "$out" "T20HEX:1b5b31333b3275"
  assert_not_contains "E4/A8 Shift+Enter is not a bare 0d/newline byte" "$out" "T20HEX:0d"

  # Same probe without enabling the kitty keyboard protocol first: kitty's
  # map sends the raw CSI u bytes unconditionally, so they must arrive
  # untouched either way (tmux's `extended-keys always` gave us exactly that).
  sleep 0.3
  zj_type 'clear; python3 ~/t20-kkp-reader.py'; zj_enter
  sleep 0.5
  # shellcheck disable=SC2086
  zj_keys_hex $hex
  sleep 1.0
  out="$(zj_pane_screen)"
  assert_contains "E4/A8 Shift+Enter reaches the pane as CSI 13;2u (no protocol request)" "$out" "T20HEX:1b5b31333b3275"
fi

t_done
