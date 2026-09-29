#!/usr/bin/env bash
# fish/conf.d/00-mux-auto.fish (contract c): guards + MUX=zellij/tmux dispatch.
# Runs fish -i interactively (stdin piped "exit\n" so it always terminates
# promptly; a pty in the loop, e.g. via `script`, made fish hang on that
# input instead) with a private HOME/XDG_CONFIG_HOME containing only the
# file under test, plus stub zellij-boot/tmux binaries that record their
# own invocation.
#
#   T70_FISH_FILE=<path>   the 00-mux-auto.fish to test. Default: the repo's.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

FISH_FILE="${T70_FISH_FILE:-$REPO/fish/.config/fish/conf.d/00-mux-auto.fish}"
OLD_FISH_FILE="$REPO/fish/.config/fish/conf.d/00-tmux-auto.fish"

t_check "00-tmux-auto.fish is gone (replaced by 00-mux-auto.fish)" test ! -e "$OLD_FISH_FILE"

if ! command -v fish >/dev/null 2>&1; then
  t_fail "fish installed" "fish not in PATH"
  t_done
  exit
fi

if [ ! -f "$FISH_FILE" ]; then
  t_fail "00-mux-auto.fish exists" "not found at $FISH_FILE"
  t_done
  exit
fi

T70_LOG="$T_ROOT/t70.log"
T70_STUB="$T_ROOT/stub"
mkdir -p "$T70_STUB" "$XDG_CONFIG_HOME/fish/conf.d" "$HOME/.config/tmux"
cp "$FISH_FILE" "$XDG_CONFIG_HOME/fish/conf.d/00-mux-auto.fish"

cat >"$T70_STUB/zellij-boot" <<'EOF'
#!/bin/bash
echo "zellij-boot $*" >>"$T70_LOG"
EOF
cat >"$T70_STUB/tmux" <<'EOF'
#!/bin/bash
echo "tmux $*" >>"$T70_LOG"
[ "$1" = "has-session" ] && exit 1
exit 0
EOF
chmod +x "$T70_STUB/zellij-boot" "$T70_STUB/tmux"
cat >"$HOME/.config/tmux/boot.sh" <<'EOF'
#!/bin/bash
echo "boot.sh" >>"$T70_LOG"
EOF
chmod +x "$HOME/.config/tmux/boot.sh"

# t70_run DESC ENVVARS... : run fish -i once with the given extra env vars
# set (in addition to a clean baseline), returning what got invoked.
t70_run() {
  # shellcheck disable=SC2034 # desc documents the call site, not read here
  local desc="$1"
  shift
  rm -f "$T70_LOG"
  : >"$T70_LOG"
  printf 'exit\n' | env -i \
    HOME="$HOME" PATH="$T70_STUB:/usr/bin:/bin" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    T70_LOG="$T70_LOG" TERM="${TERM:-xterm}" \
    "$@" \
    timeout 10 fish -i >"$T_ROOT/fish-out.log" 2>&1
  cat "$T70_LOG" 2>/dev/null
}

out="$(t70_run 'MUX=zellij + kitty' MUX=zellij KITTY_WINDOW_ID=1)"
assert_contains "MUX=zellij + KITTY_WINDOW_ID -> zellij-boot invoked" "$out" "zellij-boot"
assert_not_contains "MUX=zellij + KITTY_WINDOW_ID -> tmux path not taken" "$out" "boot.sh"

out="$(t70_run 'no KITTY_WINDOW_ID' MUX=zellij)"
assert_eq "no KITTY_WINDOW_ID -> nothing invoked" "$out" ""

out="$(t70_run 'TMUX set' MUX=zellij KITTY_WINDOW_ID=1 TMUX=/tmp/x)"
assert_eq "TMUX set -> nothing invoked (already inside a mux)" "$out" ""

out="$(t70_run 'ZELLIJ set' MUX=zellij KITTY_WINDOW_ID=1 ZELLIJ=1)"
assert_eq "ZELLIJ set -> nothing invoked (already inside a mux)" "$out" ""

out="$(t70_run 'NO_MUX=1' MUX=zellij KITTY_WINDOW_ID=1 NO_MUX=1)"
assert_eq "NO_MUX=1 -> nothing invoked" "$out" ""

out="$(t70_run 'NO_TMUX=1' MUX=zellij KITTY_WINDOW_ID=1 NO_TMUX=1)"
assert_eq "NO_TMUX=1 -> nothing invoked (legacy opt-out still honored)" "$out" ""

out="$(t70_run 'MUX unset, kitty' KITTY_WINDOW_ID=1)"
assert_contains "MUX unset -> tmux path runs (stub tmux invoked)" "$out" "tmux"
assert_not_contains "MUX unset -> zellij-boot not invoked" "$out" "zellij-boot"

out="$(t70_run 'MUX=tmux explicit, kitty' MUX=tmux KITTY_WINDOW_ID=1)"
assert_contains "MUX=tmux -> tmux path runs" "$out" "tmux"
assert_not_contains "MUX=tmux -> zellij-boot not invoked" "$out" "zellij-boot"

t_done
