#!/usr/bin/env bash
# Audit group B: every tmux-mode key and global bind (B1-B18).
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

if ! zj_start; then
  t_done
  exit
fi

# --- local helpers (t10-only, prefixed to stay out of lib.sh's namespace) ---

# t10_reaches_shell NAME TEXT : type TEXT+Enter and assert it echoes back
# (proves the current mode forwards plain keys to the pane, i.e. locked).
t10_reaches_shell() {
  local name="$1" text="$2"
  zj_type "$text"; zj_enter
  assert_contains "$name" "$(zj_pane_screen)" "$text"
}

# t10_cur_field N : field N (1-indexed, per zj_panes' TSV) of the focused
# pane IN THE ACTIVE TAB. Filtering by tab position matters: zellij marks one
# "last focused" pane per tab, so an unfiltered `focused==1` can match a
# leftover pane in a different tab.
t10_cur_field() {
  local f="$1" t
  t="$(zj_tab_pos)"
  zj_panes | awk -F'\t' -v t="$t" -v f="$f" '$1==t && $3==1{print $(f)}'
}

# t10_pane_id_at POS : the terminal pane id occupying tab position POS.
# Default tab names ("Tab #1", "Tab #2", ...) are derived from position, so
# they cannot detect a MoveTab swap; the underlying pane id can.
t10_pane_id_at() {
  local pos="$1"
  zj_panes_json | python3 -c '
import json, sys
pos = int(sys.argv[1])
for p in json.load(sys.stdin):
    if not p["is_plugin"] and p["tab_position"] == pos:
        print(p["id"]); break' "$pos"
}

# t10_tab_name_at POS : the tab-bar name currently shown at tab position POS.
t10_tab_name_at() {
  local pos="$1"
  zj_tabs | sed -n "$((pos + 1))p"
}

# --- B1: enter tmux mode with both Ctrl+b and Ctrl+a --------------------------

before="$(zj_tab_count)"
zj_keys_hex 02 63   # Ctrl+b c  (NewTab, B5)
sleep 0.3
assert_eq "B1/B5 Ctrl+b enters tmux mode, c makes a new tab" "$(zj_tab_count)" "$((before + 1))"

before="$(zj_tab_count)"
zj_keys_hex 01 63   # Ctrl+a c
sleep 0.3
assert_eq "B1/B5 Ctrl+a enters tmux mode, c makes a new tab" "$(zj_tab_count)" "$((before + 1))"

zj_first_tab        # normalize to tab 1 (position 0) for the rest
sleep 0.3

# --- B2: | and - split panes; B7: h/j/k/l move focus between them -----------

before="$(zj_pane_count)"
zj_keys_hex 02 7c   # Ctrl+b |  (split right)
sleep 0.3
assert_eq "B2 | splits a new pane right" "$(zj_pane_count)" "$((before + 1))"

foc_before="$(zj_focused)"
zj_keys_hex 02 68   # Ctrl+b h  (MoveFocus Left, back to the original pane)
sleep 0.3
if [ "$(zj_focused)" != "$foc_before" ]; then t_ok "B7 h moves focus left"; else t_fail "B7 h moves focus left" "focus unchanged"; fi

foc_before="$(zj_focused)"
zj_keys_hex 02 6c   # Ctrl+b l  (MoveFocus Right)
sleep 0.3
if [ "$(zj_focused)" != "$foc_before" ]; then t_ok "B7 l moves focus right"; else t_fail "B7 l moves focus right" "focus unchanged"; fi

before="$(zj_pane_count)"
zj_keys_hex 02 2d   # Ctrl+b -  (split down)
sleep 0.3
assert_eq "B2 - splits a new pane down" "$(zj_pane_count)" "$((before + 1))"

foc_before="$(zj_focused)"
zj_keys_hex 02 6b   # Ctrl+b k  (MoveFocus Up)
sleep 0.3
if [ "$(zj_focused)" != "$foc_before" ]; then t_ok "B7 k moves focus up"; else t_fail "B7 k moves focus up" "focus unchanged"; fi

foc_before="$(zj_focused)"
zj_keys_hex 02 6a   # Ctrl+b j  (MoveFocus Down)
sleep 0.3
if [ "$(zj_focused)" != "$foc_before" ]; then t_ok "B7 j moves focus down"; else t_fail "B7 j moves focus down" "focus unchanged"; fi

# --- B4: D / Ctrl+D never touch anything; like any unbound key they just
# cancel the prefix (tmux behaviour, see t11) -------------------------------

before_layout="$(zj_layout | md5sum)"
before_tabs="$(zj_tab_count)"
zj_keys_hex 02 44   # Ctrl+b D
sleep 0.2
assert_eq "B4 D changes nothing" "$(zj_layout | md5sum)" "$before_layout"
zj_keys_hex 02 04    # Ctrl+b Ctrl+D
sleep 0.2
assert_eq "B4 Ctrl+D changes nothing" "$(zj_layout | md5sum)" "$before_layout"
zj_keys_hex 63       # c, no prefix: must reach the shell, not open a tab
sleep 0.3
assert_eq "B4 D / Ctrl+D cancel the prefix (bare c makes no tab)" "$(zj_tab_count)" "$before_tabs"
zj_keys_hex 15        # Ctrl+U: drop the stray "c" from the prompt
sleep 0.2
zj_first_tab                   # back to a known tab 1

# --- B6/B18: C, w, s all open the session-manager floating plugin -----------

t10_assert_session_manager() {
  local name="$1"
  local sm
  sm="$(zj_panes_json | python3 -c '
import json, sys
for p in json.load(sys.stdin):
    if p.get("is_plugin") and "session-manager" in (p.get("plugin_url") or "") and p.get("is_floating"):
        print("yes"); break')"
  assert_eq "$name" "$sm" "yes"
}

zj_keys_hex 02 43; sleep 0.5   # Ctrl+b C
t10_assert_session_manager "B6 C opens the floating session-manager plugin"
zj_keys_hex 1b; sleep 0.3      # close it

zj_keys_hex 02 77; sleep 0.5   # Ctrl+b w
t10_assert_session_manager "B18 w opens the floating session-manager plugin"
zj_keys_hex 1b; sleep 0.3

zj_keys_hex 02 73; sleep 0.5   # Ctrl+b s
t10_assert_session_manager "B18 s opens the floating session-manager plugin"
zj_keys_hex 1b; sleep 0.3

# --- B12: f and z toggle fullscreen -------------------------------------------

fs_before="$(t10_cur_field 4)"
zj_keys_hex 02 66   # Ctrl+b f
sleep 0.3
fs_after="$(t10_cur_field 4)"
if [ "$fs_before" != "$fs_after" ]; then t_ok "B12 f toggles fullscreen"; else t_fail "B12 f toggles fullscreen" "flag unchanged ($fs_before)"; fi
zj_keys_hex 02 66; sleep 0.3   # back off

fs_before="$(t10_cur_field 4)"
zj_keys_hex 02 7a   # Ctrl+b z
sleep 0.3
fs_after="$(t10_cur_field 4)"
if [ "$fs_before" != "$fs_after" ]; then t_ok "B12 z toggles fullscreen"; else t_fail "B12 z toggles fullscreen" "flag unchanged ($fs_before)"; fi
zj_keys_hex 02 7a; sleep 0.3   # back off

# --- B18: x closes the focused pane ------------------------------------------

before="$(zj_pane_count)"
if [ "$before" -gt 1 ]; then
  zj_keys_hex 02 78   # Ctrl+b x
  sleep 0.3
  assert_eq "B18 x closes the focused pane" "$(zj_pane_count)" "$((before - 1))"
else
  t_fail "B18 x closes the focused pane" "setup broken: need >1 pane in the active tab, got $before"
fi

# --- 1-9 are unbound on purpose: they only cancel the prefix ---------------

zj_keys_hex 02 63; sleep 0.3   # a 2nd tab (now active) for H/L below
pos_before="$(zj_tab_pos)"
zj_keys_hex 02 31; sleep 0.3   # Ctrl+b 1
assert_eq "1 does not jump to tab 1" "$(zj_tab_pos)" "$pos_before"
before_tabs="$(zj_tab_count)"
zj_keys_hex 63; sleep 0.3      # c, no prefix: must reach the shell
assert_eq "1 cancels the prefix (bare c makes no tab)" "$(zj_tab_count)" "$before_tabs"
zj_keys_hex 15; sleep 0.2      # Ctrl+U: drop the stray "c"
zj_first_tab                   # back to a known tab 1

# --- B8: H/L move the active tab (checked by pane identity, not by name) ----

id0_before="$(t10_pane_id_at 0)"
id1_before="$(t10_pane_id_at 1)"
zj_keys_hex 02 4c   # Ctrl+b L (MoveTab Right), starting from position 0
sleep 0.3
id0_mid="$(t10_pane_id_at 0)"
id1_mid="$(t10_pane_id_at 1)"
if [ "$id0_mid" = "$id1_before" ] && [ "$id1_mid" = "$id0_before" ]; then
  t_ok "B8 L moves the active tab right (positions swap)"
else
  t_fail "B8 L moves the active tab right (positions swap)" "pos0 $id0_before->$id0_mid pos1 $id1_before->$id1_mid"
fi
zj_keys_hex 02 48   # Ctrl+b H (MoveTab Left), back
sleep 0.3
id0_after="$(t10_pane_id_at 0)"
id1_after="$(t10_pane_id_at 1)"
if [ "$id0_after" = "$id0_before" ] && [ "$id1_after" = "$id1_before" ]; then
  t_ok "B8 H moves the active tab back left"
else
  t_fail "B8 H moves the active tab back left" "pos0=$id0_after pos1=$id1_after"
fi

# --- B10: p/n are unbound on purpose (Ctrl+PgUp/Dn switch tabs) -------------

pos_before="$(zj_tab_pos)"
zj_keys_hex 02 6e   # Ctrl+b n
sleep 0.3
assert_eq "B10 n does not switch tabs" "$(zj_tab_pos)" "$pos_before"
zj_keys_hex 02 70   # Ctrl+b p
sleep 0.3
assert_eq "B10 p does not switch tabs" "$(zj_tab_pos)" "$pos_before"

# --- non-arrow tmux-mode actions return to locked afterwards ----------------

t10_reaches_shell "B18 after p, a plain letter reaches the shell (locked)" "AFTER_P_LOCKED"

# --- B11: arrows resize and STAY in tmux mode (repeatable) -------------------

cols0="$(t10_cur_field 8)"
zj_keys_hex 02 1b 5b 44   # Ctrl+b, Left arrow (CSI D)
sleep 0.3
cols1="$(t10_cur_field 8)"
zj_keys_hex 1b 5b 44       # Left arrow again, no prefix: only resizes if still in tmux mode
sleep 0.3
cols2="$(t10_cur_field 8)"
if [ "$cols0" != "$cols1" ] && [ "$cols1" != "$cols2" ]; then
  t_ok "B11 Left arrow resizes and a second bare Left arrow resizes again"
else
  t_fail "B11 Left arrow resizes and a second bare Left arrow resizes again" "cols $cols0 -> $cols1 -> $cols2"
fi
zj_keys_hex 1b   # Esc back to locked
sleep 0.2
t10_reaches_shell "B11 Esc after resizing returns to locked" "AFTER_RESIZE_LOCKED"

# --- B13: v opens the scrollback in nvim (copy-mode-vi); [ enters Scroll ------

t10_nvim_pane() { zj_panes_json | grep -q '"nvim'; }
zj_keys_hex 02 76   # Ctrl+b v
if wait_for 5 t10_nvim_pane; then t_ok "B13 v opens the scrollback in nvim"; else t_fail "B13 v opens the scrollback in nvim" "no nvim pane"; fi
zj_keys_hex 1b; zj_type ':qa!'; zj_enter   # quit nvim, back to the shell
sleep 0.5
t10_reaches_shell "B13 after v and :qa! the shell is back (locked)" "AFTER_SCROLL_V"

zj_keys_hex 02 5b   # Ctrl+b [
sleep 0.3
zj_type 'ALSO_SHOULD_NOT_REACH'
sleep 0.3
assert_not_contains "B13 [ also enters scroll mode" "$(zj_pane_screen)" "ALSO_SHOULD_NOT_REACH"
zj_keys_hex 1b
sleep 0.2
t10_reaches_shell "B13 Esc exits [ scroll mode back to locked" "AFTER_SCROLL_BRACKET"

# --- Esc and Enter in tmux mode just return to locked (no side effect) ------

before_layout="$(zj_layout | md5sum)"
zj_keys_hex 02 1b   # Ctrl+b Esc
sleep 0.2
assert_eq "Esc in tmux mode is a plain return to locked" "$(zj_layout | md5sum)" "$before_layout"
t10_reaches_shell "after tmux-mode Esc we are locked" "AFTER_TMUX_ESC"

before_layout="$(zj_layout | md5sum)"
zj_keys_hex 02 0d   # Ctrl+b Enter
sleep 0.2
assert_eq "Enter in tmux mode is a plain return to locked" "$(zj_layout | md5sum)" "$before_layout"
t10_reaches_shell "after tmux-mode Enter we are locked" "AFTER_TMUX_ENTER"

# --- B1: Ctrl+b Ctrl+b / Ctrl+a Ctrl+a deliver the literal byte -------------

zj_type 'cat -v'; zj_enter
sleep 0.3
zj_keys_hex 02 02   # Ctrl+b Ctrl+b
sleep 0.3
assert_contains "B1 Ctrl+b Ctrl+b writes a literal ^B to the pane" "$(zj_pane_screen)" '^B'
zj_keys_hex 03       # Ctrl+C, stop cat -v
sleep 0.3
zj_enter

zj_type 'cat -v'; zj_enter
sleep 0.3
zj_keys_hex 01 01   # Ctrl+a Ctrl+a
sleep 0.3
assert_contains "B1 Ctrl+a Ctrl+a writes a literal ^A to the pane" "$(zj_pane_screen)" '^A'
zj_keys_hex 03
sleep 0.3
zj_enter

# --- B18: $ renames the active tab; Enter confirms, Esc cancels -------------

pos="$(zj_tab_pos)"
zj_keys_hex 02 24   # Ctrl+b $
sleep 0.3
zj_type 't10rename'
sleep 0.2
zj_keys_hex 0d       # Enter confirms
sleep 0.3
assert_contains "B18 \$ renames the tab, Enter confirms" "$(t10_tab_name_at "$pos")" "t10rename"

renamed_name="$(t10_tab_name_at "$pos")"
zj_keys_hex 02 24   # Ctrl+b $ again
sleep 0.3
zj_type 'shouldcancel'
sleep 0.2
zj_keys_hex 1b       # Esc cancels
sleep 0.3
assert_eq "B18 \$ rename cancels with Esc (name unchanged)" "$(t10_tab_name_at "$pos")" "$renamed_name"

# --- global binds: Alt+h/j/k/l move focus, Alt+H/L move tab -----------------

zj_keys_hex 02 7c; sleep 0.3   # Ctrl+b | : guarantee a 2nd pane to focus onto
foc_before="$(zj_focused)"
zj_keys_hex 1b 68   # ESC h (Alt+h)
sleep 0.3
if [ "$(zj_focused)" != "$foc_before" ]; then
  t_ok "global Alt+h moves focus (locked mode, no prefix)"
else
  t_fail "global Alt+h moves focus (locked mode, no prefix)" "focus unchanged"
fi

# Normalize to tab 1 (position 0): MoveTab has nowhere to go further left
# from there, so probe with Alt+L (right) first, then Alt+H (left) back --
# the same boundary-safe order B8 used above for the tmux-mode H/L keys.
zj_first_tab
id0_before="$(t10_pane_id_at 0)"
id1_before="$(t10_pane_id_at 1)"
zj_keys_hex 1b 4c   # ESC L (Alt+L) : MoveTab Right
sleep 0.3
id0_mid="$(t10_pane_id_at 0)"
id1_mid="$(t10_pane_id_at 1)"
if [ "$id0_mid" = "$id1_before" ] && [ "$id1_mid" = "$id0_before" ]; then
  t_ok "global Alt+L moves the active tab right"
else
  t_fail "global Alt+L moves the active tab right" "pos0 $id0_before->$id0_mid pos1 $id1_before->$id1_mid"
fi
zj_keys_hex 1b 48   # ESC H (Alt+H) : MoveTab Left, back
sleep 0.3
id0_back="$(t10_pane_id_at 0)"
id1_back="$(t10_pane_id_at 1)"
if [ "$id0_back" = "$id0_before" ] && [ "$id1_back" = "$id1_before" ]; then
  t_ok "global Alt+H moves the active tab back left"
else
  t_fail "global Alt+H moves the active tab back left" "pos0=$id0_back pos1=$id1_back"
fi

# --- global binds: Ctrl+Shift+Left/Right switch tabs -------------------------

pos_before="$(zj_tab_pos)"
zj_keys_hex 1b 5b 31 3b 36 44   # CSI 1;6D = Ctrl+Shift+Left
sleep 0.3
pos_after="$(zj_tab_pos)"
if [ "$pos_after" != "$pos_before" ]; then
  t_ok "global Ctrl+Shift+Left switches to the previous tab"
else
  t_fail "global Ctrl+Shift+Left switches to the previous tab" "position unchanged ($pos_before)"
fi
zj_keys_hex 1b 5b 31 3b 36 43   # CSI 1;6C = Ctrl+Shift+Right
sleep 0.3
assert_eq "global Ctrl+Shift+Right switches back to the next tab" "$(zj_tab_pos)" "$pos_before"

# --- B18: d detaches the client; session stays alive (last: ends the client) -

zj_keys_hex 02 64   # Ctrl+b d
sleep 0.5
clients="$(ZJ action list-clients 2>&1)"
client_rows="$(printf '%s\n' "$clients" | tail -n +2 | grep -c . || true)"
assert_eq "B18 d detaches the client (no client rows left)" "$client_rows" "0"
t_check "B18 d leaves the session alive after detach" zj_ready

t_done
