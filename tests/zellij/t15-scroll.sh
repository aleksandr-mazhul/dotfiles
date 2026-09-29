#!/usr/bin/env bash
# Audit A5/B13: scroll mode is tmux's vi copy-mode — it must be USABLE, not
# just enterable. With clear-defaults=true nothing is bound unless we bind it.
# Assertions read the rendered screen (tmux capture), i.e. what the user sees.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

# t15_line N : the number N is visible as a whole line of the pane
t15_line() { zj_screen | grep -qxE "[[:space:]│]*$1[[:space:]│]*"; }  # │ = pane frame
t15_seen() { if t15_line "$2"; then t_ok "$1"; else t_fail "$1" "line $2 not on screen"; fi; }
t15_gone() { if t15_line "$2"; then t_fail "$1" "line $2 still on screen"; else t_ok "$1"; fi; }

if zj_start; then
  zj_type 'clear; seq 1 300'; zj_enter
  wait_for 5 t15_line 300
  t15_seen "setup: 300 lines printed, bottom visible" 300

  zj_keys_hex 02 5b                        # Ctrl+b [
  zj_keys_hex 6b 6b 6b 6b 6b 6b 6b 6b 6b 6b  # k x10
  t15_gone "A5 k scrolls up line by line" 300
  zj_keys_hex 6a 6a 6a 6a 6a 6a 6a 6a 6a 6a  # j x10
  t15_seen "A5 j scrolls back down" 300

  # zellij drops back to locked once a scroll reaches the bottom, so each
  # block below re-enters scroll mode first.
  zj_keys_hex 02 5b 15                     # Ctrl+b [, Ctrl+u
  t15_gone "A5 Ctrl+u scrolls half a page up" 300
  zj_keys_hex 04                           # Ctrl+d (one only: at the bottom
                                           # a second one would be EOF to bash)
  t15_seen "A5 Ctrl+d scrolls half a page down" 300

  zj_keys_hex 02 5b 67                     # Ctrl+b [, g
  t15_seen "A5 g jumps to the top of the scrollback" 2
  zj_keys_hex 47                           # G
  t15_seen "A5 G jumps back to the bottom" 300

  zj_keys_hex 02 5b 6b 6b 6b 6b 6b 6b 6b 6b 6b 6b  # scrolled up, then leave
  t15_gone "setup: scrolled up before Esc" 300
  zj_keys_hex 1b                           # Esc
  t15_seen "B13 Esc leaves scroll mode at the bottom (live view)" 300
  zj_type 'echo AFTER_SCROLL_OK'; zj_enter
  assert_contains "B13 after Esc typing reaches the shell again" "$(zj_screen)" "AFTER_SCROLL_OK"

  # Search: / in scroll mode, like tmux copy-mode-vi.
  zj_keys_hex 02 5b 2f                     # Ctrl+b [ /
  zj_type '150'; zj_enter
  sleep 0.3
  t15_seen "A5 / searches the scrollback (match scrolled into view)" 150
  t15_gone "A5 / search moved the view away from the bottom" 300
  zj_keys_hex 6e                           # n = next match, must not break
  t_check "A5 n (next match) keeps the session alive" zj_ready
  zj_keys_hex 1b                           # Esc leaves search/scroll
  zj_type 'echo AFTER_SEARCH_OK'; zj_enter
  assert_contains "A5 Esc leaves search back to the shell" "$(zj_screen)" "AFTER_SEARCH_OK"

  # e = open the scrollback in $scrollback_editor (nvim) — the keyboard way
  # to yank from history now that zellij has no vi selection.
  zj_keys_hex 02 5b 65                     # Ctrl+b [ e
  if wait_for 5 sh -c "zellij --session '$ZJ_S' action list-panes -a --json -c 2>/dev/null | grep -q nvim"; then
    t_ok "A5 e opens the scrollback in nvim"
  else
    t_fail "A5 e opens the scrollback in nvim" "no pane running nvim"
  fi
  zj_type ':qa!'; zj_enter
fi

t_done
