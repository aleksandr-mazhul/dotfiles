#!/usr/bin/env bash
# Audit B15/B16: tmux-resurrect's prefix+C-s (save) and prefix+C-r (restore)
# muscle memory. zellij serializes on its own, so C-s only has to leave
# tmux-mode cleanly; C-r opens the session-manager (its resurrect list).
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

t12_has_session_manager() {
  zj_panes_json | python3 -c '
import json, sys
sys.exit(0 if any(p["is_plugin"] and p["is_floating"] and "session-manager" in (p.get("plugin_url") or "")
                  for p in json.load(sys.stdin)) else 1)'
}

if zj_start; then
  tabs_before="$(zj_tab_count)"
  zj_keys_hex 02 13                        # Ctrl+b Ctrl+s
  zj_type 'echo AFTER_CTRL_S'; zj_enter
  # If C-s left us in tmux-mode, the "c" in "echo" would open a new tab.
  assert_eq "B15 Ctrl+b Ctrl+s leaves no key for tmux-mode (tab count unchanged)" "$(zj_tab_count)" "$tabs_before"
  assert_contains "B15 Ctrl+b Ctrl+s returns to locked (typing reaches the shell)" "$(zj_pane_screen)" "AFTER_CTRL_S"
  t_check "B15 Ctrl+b Ctrl+s keeps the session alive" zj_ready

  zj_keys_hex 02 12                        # Ctrl+b Ctrl+r
  if wait_for 5 t12_has_session_manager; then
    t_ok "B16 Ctrl+b Ctrl+r opens the session-manager (resurrect list)"
  else
    t_fail "B16 Ctrl+b Ctrl+r opens the session-manager (resurrect list)" "no floating session-manager pane"
  fi
fi

t_done
