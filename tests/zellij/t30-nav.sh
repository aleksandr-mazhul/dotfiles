#!/usr/bin/env bash
# Audit group D: seamless Super+hjkl (kitty -> ESC/Alt+hjkl) navigation between
# nvim splits and zellij panes. Real repo nvim config +
# vim-zellij-navigator; contract: MoveFocus in zellij, or pass the key to
# nvim when nvim is the focused pane (D1-D5).
#
# T30_NVIM_EXTRA: extra nvim args, spliced in before our own `-c vsplit`.
# Empty by default (the committed test exercises the real repo config only);
# set it to point a scratch prototype nvim at a zellij-aware overlay.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"
zj_install_config

NVIM_SOCK="$T_ROOT/t30-nvim.sock"

# t30_nvim_remote EXPR : evaluate an expression against the running nvim.
t30_nvim_remote() { nvim --server "$NVIM_SOCK" --remote-expr "$1" 2>/dev/null; }
t30_nvim_ready()  { [ -S "$NVIM_SOCK" ] && [ "$(t30_nvim_remote 1)" = "1" ]; }
# Focus nvim's top-left window (i.e. the leftmost one after a plain vsplit).
t30_nvim_focus_left() { t30_nvim_remote "execute('wincmd t')" >/dev/null; }
t30_nvim_cur_win()    { t30_nvim_remote 'win_getid()'; }
# t30_wait_focus PANE_ID : poll (a MessagePlugin move-focus round trip is
# async) until zellij's focused pane matches, up to 5s. Always returns 0 so
# the caller's assert_eq reports the actual (possibly stale) value on timeout.
T30_WANT_FOCUS=""
t30_focus_is_want() { [ "$(zj_focused)" = "$T30_WANT_FOCUS" ]; }
t30_wait_focus() { T30_WANT_FOCUS="$1"; wait_for 5 t30_focus_is_want; }

if ! zj_start; then
  t_done
  exit
fi
if ! zj_need_plugins vim-zellij-navigator; then
  t_done
  exit
fi

# --- scenario setup: nvim (left, vsplit) | shell (top-right) / shell (bottom-right) ---
NVIM_PANE="$(zj_focused)"
launch_cmd="env XDG_CONFIG_HOME=\"$REAL_HOME/.config\" XDG_DATA_HOME=\"$REAL_HOME/.local/share\" XDG_STATE_HOME=\"$REAL_HOME/.local/state\" XDG_CACHE_HOME=\"$REAL_HOME/.cache\" nvim -i NONE --listen \"$NVIM_SOCK\" ${T30_NVIM_EXTRA:-} -c vsplit"
zj_type "$launch_cmd"
zj_enter

if ! wait_for 25 t30_nvim_ready; then
  t_fail "nvim starts with a vsplit inside the zellij pane" "$(zj_pane_screen)"
  t_done
  exit
fi
t_ok "nvim starts with a vsplit inside the zellij pane"
t30_nvim_focus_left

RIGHT_TOP="$(ZJ action new-pane -d right 2>/dev/null | tail -1)"
if [ -z "$RIGHT_TOP" ]; then
  t_fail "create shell pane to the right of nvim" "new-pane returned nothing"
  t_done
  exit
fi

# Back to nvim, left window, as the scenario's starting state.
ZJ action focus-pane-id "$NVIM_PANE" >/dev/null 2>&1
sleep 0.3
t30_nvim_focus_left
WIN_LEFT="$(t30_nvim_cur_win)"
assert_eq "D1 nvim's left window is focused to start" "$(zj_focused)" "$NVIM_PANE"

# --- D1: Alt+l inside nvim moves the split, then leaves nvim to zellij ---
zj_keys_hex 1b 6c   # ESC l
sleep 0.4
WIN_AFTER1="$(t30_nvim_cur_win)"
if [ -n "$WIN_AFTER1" ] && [ "$WIN_AFTER1" != "$WIN_LEFT" ]; then
  t_ok "D1 Alt+l moves nvim's own split (left -> right window)"
else
  t_fail "D1 Alt+l moves nvim's own split (left -> right window)" "window id unchanged: [$WIN_LEFT]"
fi
assert_eq "D1 Alt+l inside nvim's split leaves zellij focus unchanged" "$(zj_focused)" "$NVIM_PANE"

zj_keys_hex 1b 6c   # ESC l again, at nvim's rightmost window
t30_wait_focus "$RIGHT_TOP"
assert_eq "D1 Alt+l at nvim's rightmost split moves zellij focus right" "$(zj_focused)" "$RIGHT_TOP"
assert_eq "D1 nvim's own window is unchanged by the zellij-level move" "$(t30_nvim_cur_win)" "$WIN_AFTER1"

# --- D1: Alt+h from the shell pane returns zellij focus to nvim, nvim state kept ---
zj_keys_hex 1b 68   # ESC h
t30_wait_focus "$NVIM_PANE"
assert_eq "D1 Alt+h from shell returns zellij focus to nvim pane" "$(zj_focused)" "$NVIM_PANE"
assert_eq "D1 nvim's current window is still the right one" "$(t30_nvim_cur_win)" "$WIN_AFTER1"

# --- D1: two shell panes stacked vertically, Alt+j / Alt+k move zellij focus ---
ZJ action focus-pane-id "$RIGHT_TOP" >/dev/null 2>&1
sleep 0.3
RIGHT_BOTTOM="$(ZJ action new-pane -d down 2>/dev/null | tail -1)"
if [ -z "$RIGHT_BOTTOM" ]; then
  t_fail "create second shell pane below the first" "new-pane returned nothing"
  t_done
  exit
fi
ZJ action focus-pane-id "$RIGHT_TOP" >/dev/null 2>&1
sleep 0.3
zj_keys_hex 1b 6a   # ESC j
t30_wait_focus "$RIGHT_BOTTOM"
assert_eq "D1 Alt+j moves zellij focus down between shell panes" "$(zj_focused)" "$RIGHT_BOTTOM"

zj_keys_hex 1b 6b   # ESC k
t30_wait_focus "$RIGHT_TOP"
assert_eq "D1 Alt+k moves zellij focus up between shell panes" "$(zj_focused)" "$RIGHT_TOP"

# --- D1: Alt+h with nothing to the left leaves no garbage in the pane ---
if ZJ action new-tab >/dev/null 2>&1; then
  sleep 0.5
  zj_keys_hex 1b 68   # ESC h, nothing to its left
  sleep 0.3
  zj_type 'echo NAVCANARY_D1'
  zj_enter
  screen="$(zj_pane_screen)"
  assert_contains "D1 Alt+h with nothing to the left: canary command still runs" "$screen" "NAVCANARY_D1"
  assert_not_contains "D1 Alt+h with nothing to the left: no stray key in the prompt" "$screen" "hecho NAVCANARY_D1"
else
  t_fail "D1 Alt+h with nothing to the left: canary command still runs" "could not open a fresh tab"
fi

t_done
