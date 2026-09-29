#!/usr/bin/env bash
# zellij-boot (contract b): pick the right session to attach/resurrect from
# `zellij list-sessions --no-formatting`, without truncating names that
# contain spaces.
#
#   T65_BIN_DIR=<dir>   directory holding zellij-boot (and its
#                        zellij-resurrect-filter sibling). Default: the
#                        repo's bin/.local/bin.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

BIN_DIR="${T65_BIN_DIR:-$REPO/bin/.local/bin}"
BOOT="$BIN_DIR/zellij-boot"

if [ ! -x "$BOOT" ]; then
  t_fail "zellij-boot exists and is executable" "not found at $BOOT"
  t_done
  exit
fi

if ! command -v zellij >/dev/null 2>&1; then
  t_fail "zellij installed" "zellij not in PATH"
  t_done
  exit
fi

# Real sessions need session_serialization to leave a resurrectable EXITED
# entry, and enough config to skip the first-run wizard tab.
mkdir -p "$XDG_CONFIG_HOME/zellij"
cat >"$XDG_CONFIG_HOME/zellij/config.kdl" <<'EOF'
show_startup_tips false
show_release_notes false
session_serialization true
serialize_pane_viewport true
EOF

# One tmux session hosts a window per zellij process so several can be live
# at once; each window keeps running (echo+sleep) after zellij exits so the
# window itself never needs to be recreated per spawn.
TM new-session -d -s drv -x 80 -y 24 -n idle "bash --norc"

_t65_win=0
# t65_spawn NAME : start a real zellij session with the given name, wait
# until it answers actions. Each call gets its own tmux window.
t65_spawn() {
  local name="$1"
  _t65_win=$((_t65_win + 1))
  TM new-window -t drv -n "w$_t65_win" \
    "zellij --session '$name'; echo ZELLIJ_EXITED \$?; sleep 30"
  wait_for 10 zellij --session "$name" action query-tab-names
}

# t65_to_exited NAME : save-session then kill it, leaving it EXITED and
# resurrectable (list-sessions shows "(EXITED - attach to resurrect)").
t65_to_exited() {
  local name="$1"
  zellij --session "$name" action save-session >/dev/null 2>&1
  sleep 0.3
  zellij kill-session "$name" >/dev/null 2>&1
  wait_for 10 sh -c "zellij list-sessions --no-formatting 2>/dev/null | grep -qF '$name [Created' "
}

# t65_boot : run zellij-boot in dry-run mode (it prints the command it would
# exec instead of exec'ing it) and echo what it printed.
t65_boot() { ZELLIJ_BOOT_DRY_RUN=1 "$BOOT"; }

t65_cleanup_all() {
  zellij kill-all-sessions -y >/dev/null 2>&1
  zellij delete-all-sessions -y -f >/dev/null 2>&1
  sleep 0.3
}

# --- no sessions at all -> starts `main` -------------------------------------

t65_cleanup_all
out="$(t65_boot)"
assert_eq "no sessions -> attach -c main" "$out" "zellij attach -c main "

# --- one live session -> attaches it -----------------------------------------

t65_cleanup_all
if t65_spawn plainlive; then
  out="$(t65_boot)"
  assert_eq "one live session -> attach <it>" "$out" "zellij attach plainlive "
else
  t_fail "one live session -> attach <it>" "plainlive never became ready"
fi

# --- live + exited -> attaches the live one, not the exited one -------------

t65_cleanup_all
if t65_spawn oldexited && t65_to_exited oldexited && t65_spawn freshlive; then
  out="$(t65_boot)"
  assert_eq "live + exited -> attach the live one" "$out" "zellij attach freshlive "
else
  t_fail "live + exited -> attach the live one" "setup failed: $(zellij list-sessions --no-formatting 2>&1)"
fi

# --- only exited -> attaches with --force-run-commands, and runs the filter -

t65_cleanup_all
if t65_spawn onlyexited && t65_to_exited onlyexited; then
  out="$(t65_boot)"
  assert_eq "only exited -> attach <it> --force-run-commands" "$out" "zellij attach onlyexited --force-run-commands "
else
  t_fail "only exited -> attach <it> --force-run-commands" "onlyexited never became resurrectable"
fi

# --- a session name containing a space is passed intact ---------------------

t65_cleanup_all
if t65_spawn "two words"; then
  out="$(t65_boot)"
  assert_eq "space in a live session name is passed intact" "$out" 'zellij attach two\ words '
else
  t_fail "space in a live session name is passed intact" "'two words' never became ready"
fi

t65_cleanup_all
if t65_spawn "spaced exited" && t65_to_exited "spaced exited"; then
  out="$(t65_boot)"
  assert_eq "space in an exited session name is passed intact" "$out" \
    'zellij attach spaced\ exited --force-run-commands '
else
  t_fail "space in an exited session name is passed intact" "'spaced exited' never became resurrectable"
fi

t65_cleanup_all
t_done
