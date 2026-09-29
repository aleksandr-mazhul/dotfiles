#!/usr/bin/env bash
# tmux key parity, round 2: tmux's STOCK prefix table (not only the binds in
# .tmux.conf) plus the zellij-only extras on otherwise free letters, and the
# rule that makes zellij feel like tmux: an unbound key after the prefix just
# cancels it instead of leaving tmux-mode armed.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

# t11_mode_locked NAME : typed text reaches the shell and no tab was created
t11_back_to_locked() {
  local tabs; tabs="$(zj_tab_count)"
  zj_type "echo $2"; zj_enter
  if [ "$(zj_tab_count)" = "$tabs" ] && zj_pane_screen | grep -qF "$2"; then
    t_ok "$1"
  else
    t_fail "$1" "tmux-mode still armed (tabs $tabs -> $(zj_tab_count))"
  fi
}
# t11_floating_cmd WORD : a floating terminal pane whose command/title has WORD
t11_floating_cmd() {
  zj_panes_json | python3 -c '
import json, sys
w = sys.argv[1]
sys.exit(0 if any(p["is_floating"] and not p["is_plugin"] and
                  w in ((p.get("terminal_command") or "") + " " + (p.get("title") or ""))
                  for p in json.load(sys.stdin)) else 1)' "$1"
}
t11_floating_count() { zj_panes_json | python3 -c 'import json,sys; print(sum(1 for p in json.load(sys.stdin) if p["is_floating"] and not p["is_plugin"]))'; }
t11_focused_x() { zj_panes | awk -F'\t' '$3==1 && $5==0 {print $6; exit}'; }
t11_geom() { local t; t="$(zj_tab_pos)"; zj_panes | awk -F'\t' -v t="$t" '$1==t && $5==0 {print $2":"$6","$7","$8","$9}' | sort | tr '\n' ' '; }

zj_start || { t_done; exit; }

# --- the prefix cancels on any unbound key (tmux behaviour) ------------------
for k in 71 72 25 22 61 44 30 3a; do          # q r % " a D 0 :
  zj_keys_hex 02 "$k"
  t11_back_to_locked "unbound key 0x$k after the prefix cancels it" "CANCEL_$k"
done

# --- panes ------------------------------------------------------------------
zj_keys_hex 02 7c; sleep 0.3                 # | : two panes side by side
left_right_before="$(zj_focused)"
zj_keys_hex 02 6f                            # o : next pane
if [ "$(zj_focused)" != "$left_right_before" ]; then t_ok "o focuses the next pane"; else t_fail "o focuses the next pane" "focus unchanged"; fi
after_o="$(zj_focused)"
zj_keys_hex 02 3b                            # ; : last pane
assert_eq "; returns to the previously focused pane" "$(zj_focused)" "$left_right_before"
zj_keys_hex 02 3b
assert_eq "; again toggles back" "$(zj_focused)" "$after_o"

x_before="$(t11_focused_x)"
zj_keys_hex 02 7b                            # { : swap with previous pane
x_after="$(t11_focused_x)"
if [ "$x_before" != "$x_after" ]; then t_ok "{ swaps the pane with its neighbour"; else t_fail "{ swaps the pane with its neighbour" "x stayed $x_before"; fi
zj_keys_hex 02 7d                            # } : and back
assert_eq "} swaps it back" "$(t11_focused_x)" "$x_before"

zj_keys_hex 02 2d; sleep 0.3                 # - : a third pane for layouts
g_before="$(t11_geom)"
# Space : next layout. zellij starts the cycle at the swap layout matching
# the current arrangement, so the change can take a second press.
changed=0
for _ in 1 2 3; do
  zj_keys_hex 02 20; sleep 0.3
  [ "$(t11_geom)" != "$g_before" ] && { changed=1; break; }
done
if [ "$changed" = 1 ]; then t_ok "Space cycles to the next layout"; else t_fail "Space cycles to the next layout" "geometry unchanged: $g_before"; fi

tabs="$(zj_tab_count)"; panes="$(zj_pane_count)"
zj_keys_hex 02 21                            # ! : break pane to a new tab
sleep 0.3
assert_eq "! moves the pane to a new tab" "$(zj_tab_count)" "$((tabs + 1))"

# --- tabs -------------------------------------------------------------------
pos_new="$(zj_tab_pos)"
zj_first_tab                                 # first tab
zj_keys_hex 02 09                            # Tab : last tab
assert_eq "Tab jumps back to the last tab" "$(zj_tab_pos)" "$pos_new"
zj_keys_hex 02 09
assert_eq "Tab again returns" "$(zj_tab_pos)" "0"
[ "$panes" -ge 3 ] || t_fail "setup: three panes before !" "had $panes"

tabs="$(zj_tab_count)"
zj_keys_hex 02 26                            # & : close tab, asks first
if wait_for 5 t11_floating_cmd close-tab; then t_ok "& asks before closing the tab"; else t_fail "& asks before closing the tab" "no confirm pane"; fi
zj_keys_hex 6e                               # n
sleep 0.5
assert_eq "& then n keeps the tab" "$(zj_tab_count)" "$tabs"
zj_keys_hex 02 26
wait_for 5 t11_floating_cmd close-tab
zj_keys_hex 79                               # y
if wait_for 5 sh -c "[ \"\$(zellij --session '$ZJ_S' action query-tab-names 2>/dev/null | grep -c .)\" = $((tabs - 1)) ]"; then
  t_ok "& then y closes the tab"
else
  t_fail "& then y closes the tab" "tabs $(zj_tab_count)"
fi

# --- floating / zellij extras ------------------------------------------------
zj_keys_hex 02 67                            # g : floating layer
if wait_for 3 sh -c "[ \"\$(zellij --session '$ZJ_S' action list-panes -a --json | python3 -c 'import json,sys; print(sum(1 for p in json.load(sys.stdin) if p[\"is_floating\"] and not p[\"is_plugin\"]))')\" -ge 1 ]"; then
  t_ok "g shows the floating layer (opens a floating shell)"
else
  t_fail "g shows the floating layer (opens a floating shell)"
fi
zj_keys_hex 02 67                            # g again hides it
zj_keys_hex 02 7c; sleep 0.3                 # zellij won't float a tab's last tiled pane
fl="$(t11_floating_count)"
zj_keys_hex 02 65                            # e : float <-> embed the focused pane
sleep 0.3
if [ "$(t11_floating_count)" != "$fl" ]; then t_ok "e floats/embeds the focused pane"; else t_fail "e floats/embeds the focused pane" "floating count stayed $fl"; fi
zj_keys_hex 02 65                            # put it back
if wait_for 3 sh -c "[ \"\$(zellij --session '$ZJ_S' action list-panes -a --json | python3 -c 'import json,sys; print(sum(1 for p in json.load(sys.stdin) if p[\"is_floating\"] and not p[\"is_plugin\"]))')\" = $fl ]"; then
  t_ok "e again puts the pane back"
else
  t_fail "e again puts the pane back" "floating count $(t11_floating_count), want $fl"
fi

zj_keys_hex 02 7c; sleep 0.3                 # two panes for sync
zj_keys_hex 02 53                            # S : sync input to all panes
# shellcheck disable=SC2016 # expanded by the pane's shell: only real output says SYNC_42
zj_type 'echo SYNC_$((40+2))'; zj_enter
sleep 0.3
zj_keys_hex 02 53                            # S off
other="$(zj_panes | awk -F'\t' -v t="$(zj_tab_pos)" '$1==t && $3==0 && $5==0 {print $2; exit}')"
if ZJ action dump-screen -p "terminal_$other" 2>/dev/null | grep -q SYNC_42; then
  t_ok "S sends typing to every pane in the tab"
else
  t_fail "S sends typing to every pane in the tab" "other pane terminal_$other did not get it"
fi

zj_keys_hex 02 3f                            # ? : cheatsheet
if wait_for 5 t11_floating_cmd glow; then t_ok "? opens the cheatsheet (glow, floating)"; else t_fail "? opens the cheatsheet (glow, floating)"; fi
zj_type 'q'
t_check "cheatsheet file ships with the config" test -s "$XDG_CONFIG_HOME/zellij/cheatsheet.md"

zj_keys_hex 02 74                            # t : clock
if wait_for 5 t11_floating_cmd peaclock; then t_ok "t opens a clock (peaclock, floating)"; else t_fail "t opens a clock (peaclock, floating)"; fi
zj_type 'q'

# --- scroll entry + extra scroll keys ----------------------------------------
zj_keys_hex 02 63; sleep 0.5                 # fresh tab: no floats/sync left over
zj_type 'clear; seq 1 300'; zj_enter; sleep 0.5
zj_keys_hex 02 1b 5b 35 7e                   # Ctrl+b PageUp
t11_line() { zj_screen | grep -qxE "[[:space:]│]*$1[[:space:]│]*"; }  # │ = pane frame
if t11_line 300; then t_fail "PageUp enters scroll mode a page up"; else t_ok "PageUp enters scroll mode a page up"; fi
zj_keys_hex 0d                               # Enter leaves (tmux copy-mode Enter)
if wait_for 2 t11_line 300; then t_ok "Enter leaves scroll mode at the bottom"; else t_fail "Enter leaves scroll mode at the bottom"; fi
zj_keys_hex 02 5b 19 19 19                   # Ctrl+b [, Ctrl+y x3 (line 1 is the prompt)
if t11_line 300; then t_fail "Ctrl+y scrolls up a line"; else t_ok "Ctrl+y scrolls up a line"; fi
zj_keys_hex 05 05                            # Ctrl+e x2 (a 3rd would hit the bottom and exit)
if wait_for 2 t11_line 300; then t_ok "Ctrl+e scrolls down a line"; else t_fail "Ctrl+e scrolls down a line"; fi
zj_keys_hex 02 5b 3f                         # Ctrl+b [ ?
zj_type '120'; zj_enter; sleep 0.3
if t11_line 120; then t_ok "? searches like /"; else t_fail "? searches like /"; fi
zj_keys_hex 1b

t_check "session alive at the end" zj_ready
t_done
