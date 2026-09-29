# shellcheck shell=bash
# shellcheck disable=SC2119,SC2120 # zj_start takes optional zellij args
# Test harness for the zellij migration. Source it from a t*.sh file.
#
# Isolation: every test file gets its own temp root with a private HOME,
# XDG dirs, zellij socket dir and tmux socket. The repo's zellij package is
# COPIED into that HOME (never symlinked) — theme-render and zellij itself
# write into ~/.config/zellij, and a symlink would make a test write into
# the repo.
#
# Driver: zellij runs inside a detached tmux on a private socket. tmux is
# only a programmable PTY here — `send-keys -H` delivers raw bytes exactly as
# kitty would, so tests exercise the same kitty -> zellij path as real keys.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# ZJ_PKG_OVERRIDE: point tests at a scratch prototype config instead of the repo package.
ZJ_PKG="${ZJ_PKG_OVERRIDE:-$REPO/zellij/.config/zellij}"
KITTY_CONF="$REPO/kitty/.config/kitty/kitty.conf"
REAL_HOME="${REAL_HOME:-$HOME}"

T_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/zjtest.XXXXXX")"
export HOME="$T_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$T_ROOT/cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export ZELLIJ_SOCKET_DIR="$T_ROOT/zsock"
export SHELL=/bin/bash
unset ZELLIJ ZELLIJ_SESSION_NAME TMUX TMUX_PANE KITTY_WINDOW_ID MUX NO_MUX NO_TMUX
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$ZELLIJ_SOCKET_DIR"

# Plain prompt so screen assertions are stable.
printf 'PS1="$ "\n' >"$HOME/.bashrc"

ZJ_S="t$$"          # zellij session name for this test file
TM_SOCK="$T_ROOT/tmux.sock"
_PASS=0
_FAIL=0

# --- output -------------------------------------------------------------------
t_ok()   { _PASS=$((_PASS + 1)); printf '  ok   %s\n' "$1"; }
t_fail() { _FAIL=$((_FAIL + 1)); printf '  FAIL %s\n' "$1"; [ -n "${2:-}" ] && printf '       %s\n' "$2"; return 0; }
t_skip() { printf '  skip %s (%s)\n' "$1" "$2"; }
# t_check NAME CMD... : pass if CMD succeeds
t_check() { local n="$1"; shift; if "$@" >/dev/null 2>&1; then t_ok "$n"; else t_fail "$n" "command failed: $*"; fi; }
assert_eq() { if [ "$2" = "$3" ]; then t_ok "$1"; else t_fail "$1" "expected [$3], got [$2]"; fi; }
assert_contains() { if printf '%s' "$2" | grep -qF -- "$3"; then t_ok "$1"; else t_fail "$1" "missing [$3]"; fi; }
assert_not_contains() { if printf '%s' "$2" | grep -qF -- "$3"; then t_fail "$1" "unexpected [$3]"; else t_ok "$1"; fi; }
# Call last: prints the summary and sets the exit code.
t_done() { printf '  -- %d passed, %d failed\n' "$_PASS" "$_FAIL"; [ "$_FAIL" -eq 0 ]; }

# wait_for TIMEOUT_S CMD... : poll every 0.1s until CMD succeeds
wait_for() {
  local t="$1"; shift
  local end=$(( $(date +%s%N) / 1000000 + t * 1000 ))
  while [ $(( $(date +%s%N) / 1000000 )) -lt "$end" ]; do
    "$@" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

# --- environment ----------------------------------------------------------------
# zj_install_config: copy the repo package into the temp HOME, plus the
# prebuilt plugins (fetched by zellij-plugins-fetch into the REAL home).
zj_install_config() {
  rm -rf "$XDG_CONFIG_HOME/zellij"
  if [ -d "$ZJ_PKG" ]; then
    cp -rL "$ZJ_PKG" "$XDG_CONFIG_HOME/zellij"
  else
    mkdir -p "$XDG_CONFIG_HOME/zellij"
  fi
  if [ -d "$REAL_HOME/.local/share/zellij/plugins" ]; then
    mkdir -p "$XDG_DATA_HOME/zellij"
    cp -r "$REAL_HOME/.local/share/zellij/plugins" "$XDG_DATA_HOME/zellij/"
  fi
  zj_grant_plugins
}

# Wasm plugins ask for permissions on first load, and the prompt cannot be
# answered from a test (borderless plugin panes are not focusable). zellij
# keeps grants in $XDG_CACHE_HOME/zellij/permissions.kdl keyed by the plugin's
# ABSOLUTE path (verified on 0.45.1: "file:..." and "~" keys are ignored).
ZJ_PERMS="ReadApplicationState ChangeApplicationState OpenFiles RunCommands OpenTerminalsOrPlugins WriteToStdin MessageAndLaunchOtherPlugins ReadCliPipes Reconfigure"
zj_grant_plugins() {
  local f p
  mkdir -p "$XDG_CACHE_HOME/zellij"
  f="$XDG_CACHE_HOME/zellij/permissions.kdl"
  : >"$f"
  for w in "$XDG_DATA_HOME"/zellij/plugins/*.wasm; do
    [ -e "$w" ] || continue
    printf '"%s" {\n' "$w" >>"$f"
    for p in $ZJ_PERMS; do printf '    %s\n' "$p" >>"$f"; done
    printf '}\n' >>"$f"
  done
}
# Real-home plugins are a prerequisite for status/nav tests.
zj_need_plugins() {
  local w
  for w in "$@"; do
    [ -e "$XDG_DATA_HOME/zellij/plugins/$w.wasm" ] || { t_fail "plugin $w.wasm present" "run zellij-plugins-fetch (expects ~/.local/share/zellij/plugins/$w.wasm)"; return 1; }
  done
}

TM() { tmux -S "$TM_SOCK" -f /dev/null "$@"; }
ZJ() { zellij --session "$ZJ_S" "$@"; }

# zj_start [extra zellij args...]: start zellij in the tmux driver, wait until
# the session answers actions. Returns non-zero if it never comes up.
zj_start() {
  command -v zellij >/dev/null || { t_fail "zellij installed" "zellij not in PATH"; return 1; }
  TM new-session -d -s drv -x 200 -y 50 \
    "zellij --session '$ZJ_S' $*; echo ZELLIJ_EXITED \$?; sleep 30"
  TM set -g -t drv remain-on-exit on >/dev/null 2>&1
  if ! wait_for 15 zj_ready; then
    t_fail "zellij session starts" "$(TM capture-pane -p -t drv 2>/dev/null | head -20)"
    return 1
  fi
  sleep 0.5   # let the first shell prompt draw
}
zj_ready() { ZJ action query-tab-names >/dev/null 2>&1; }

# zj_keys_hex HEX... : raw bytes into zellij's stdin, e.g. zj_keys_hex 02 63
zj_keys_hex() { TM send-keys -t drv -H "$@"; sleep 0.3; }
# zj_type TEXT : literal text (no key-name parsing)
zj_type() { TM send-keys -t drv -l -- "$1"; sleep 0.2; }
zj_enter() { zj_keys_hex 0d; }

# kitty_map_hex KEYS : hex bytes of a `map KEYS send_text all ...` line in
# kitty.conf, e.g. kitty_map_hex ctrl+page_up -> "1b 5b 31 3b 36 44". Tests use this so
# they break if kitty.conf and the zellij binds drift apart.
kitty_map_hex() {
  python3 - "$KITTY_CONF" "$1" <<'PY'
import re, sys
conf, keys = sys.argv[1], sys.argv[2]
for line in open(conf, encoding="utf-8"):
    m = re.match(r"\s*map\s+(\S+)\s+send_text\s+\S+\s+(.*?)\s*$", line)
    if not m or m.group(1) != keys:
        continue
    raw = m.group(2).encode().decode("unicode_escape").encode("latin-1")
    print(" ".join(f"{b:02x}" for b in raw))
    sys.exit(0)
sys.exit(1)
PY
}

zj_layout() { ZJ action dump-layout 2>/dev/null; }
zj_tabs()   { ZJ action query-tab-names 2>/dev/null; }
zj_screen() { TM capture-pane -p -t drv 2>/dev/null; }
# Screen of the focused pane only (zellij's own dump, no chrome).
zj_pane_screen() { ZJ action dump-screen 2>/dev/null; }
# Pane of the (single) client, e.g. "terminal_2".
zj_focused() { ZJ action list-clients 2>/dev/null | awk 'NR==2{print $2}'; }
# 0-based position of the active tab.
# (current-tab-info needs a client context, so derive it from the client's
# focused pane instead.)
zj_tab_pos() {
  local f; f="$(zj_focused)"
  zj_panes_json | python3 -c '
import json, sys
kind, _, num = sys.argv[1].partition("_")
try: panes = json.load(sys.stdin)
except Exception: sys.exit(0)
for p in panes:
    if str(p["id"]) == num and p["is_plugin"] == (kind == "plugin"):
        print(p["tab_position"]); break' "$f"
}
# zj_first_tab: focus tab 1 via the keyboard (Ctrl+Shift+Left, wraps). A CLI
# `action go-to-tab` has no client context and would not move the client.
zj_first_tab() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(zj_tab_pos)" = 0 ] && return 0
    zj_keys_hex 1b 5b 31 3b 36 44; sleep 0.2
  done
  [ "$(zj_tab_pos)" = 0 ]
}
# Raw pane list as JSON (zellij 0.45: every pane, all tabs, with geometry,
# focus, fullscreen, floating, command, exit state, tab_position).
zj_panes_json() { ZJ action list-panes -a --json 2>/dev/null; }
# zj_panes : one TSV line per TERMINAL pane:
#   tab_position id focused fullscreen floating x y cols rows exited command
zj_panes() {
  zj_panes_json | python3 -c '
import json, sys
try: panes = json.load(sys.stdin)
except Exception: sys.exit(0)
for p in panes:
    if p.get("is_plugin"): continue
    print("\t".join(str(v) for v in (
        p["tab_position"], p["id"], int(p["is_focused"]), int(p["is_fullscreen"]),
        int(p["is_floating"]), p["pane_x"], p["pane_y"], p["pane_columns"],
        p["pane_rows"], int(p["exited"]), p.get("terminal_command") or "")))'
}
# Terminal panes in the active tab.
zj_pane_count() { local t; t="$(zj_tab_pos)"; zj_panes | awk -F'\t' -v t="$t" '$1==t' | wc -l; }
zj_tab_count() { zj_tabs | grep -c .; }

cleanup() {
  zellij kill-all-sessions -y >/dev/null 2>&1
  zellij delete-all-sessions -y -f >/dev/null 2>&1
  TM kill-server >/dev/null 2>&1
  rm -rf "$T_ROOT"
}
trap cleanup EXIT
