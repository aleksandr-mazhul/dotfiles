#!/usr/bin/env bash
# The bar shows the input mode whenever it is not locked — PowerKit's prefix /
# copy-mode indicator. In zellij this matters more than in tmux: an unbound
# key does NOT drop tmux-mode, so the next letters would still fire actions.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config
zj_need_plugins zjstatus || { t_done; exit; }

t55_bar() { zj_screen | head -1; }
t55_bar_has() { t55_bar | grep -qF -- "$1"; }

if zj_start; then
  wait_for 5 t55_bar_has "Tab #1"
  bar="$(t55_bar)"
  for m in TMUX SCROLL SEARCH RENAME; do
    assert_not_contains "locked mode shows no $m indicator" "$bar" "$m"
  done

  zj_keys_hex 02                           # Ctrl+b
  if wait_for 3 t55_bar_has TMUX; then t_ok "Ctrl+b shows a TMUX indicator in the bar"; else t_fail "Ctrl+b shows a TMUX indicator in the bar" "$(t55_bar)"; fi
  zj_keys_hex 1b                           # Esc
  if wait_for 3 sh -c "! tmux -S '$TM_SOCK' capture-pane -p -t drv | head -1 | grep -qF TMUX"; then
    t_ok "Esc clears the TMUX indicator"
  else
    t_fail "Esc clears the TMUX indicator" "$(t55_bar)"
  fi

  zj_type 'seq 1 200'; zj_enter
  zj_keys_hex 02 5b 6b                     # Ctrl+b [ k
  if wait_for 3 t55_bar_has SCROLL; then t_ok "scroll mode shows a SCROLL indicator"; else t_fail "scroll mode shows a SCROLL indicator" "$(t55_bar)"; fi
  zj_keys_hex 2f                           # /
  if wait_for 3 t55_bar_has SEARCH; then t_ok "search input shows a SEARCH indicator"; else t_fail "search input shows a SEARCH indicator" "$(t55_bar)"; fi
  zj_keys_hex 1b                           # Esc: search input -> scroll (one ESC per
                                           # write: two would parse as Alt+Esc)
  # tmux's prefix works inside copy-mode, so Ctrl+b must be the prefix in
  # scroll mode too.
  zj_keys_hex 02                           # Ctrl+b from scroll mode
  if wait_for 3 t55_bar_has TMUX; then t_ok "Ctrl+b from scroll mode enters tmux-mode"; else t_fail "Ctrl+b from scroll mode enters tmux-mode" "$(t55_bar)"; fi
  zj_keys_hex 1b

  zj_keys_hex 02 24                        # Ctrl+b $
  if wait_for 3 t55_bar_has RENAME; then t_ok "rename-tab shows a RENAME indicator"; else t_fail "rename-tab shows a RENAME indicator" "$(t55_bar)"; fi
  zj_keys_hex 1b
fi

t_done
