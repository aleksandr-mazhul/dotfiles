#!/usr/bin/env bash
# fish/conf.d/zellij-tab-name.fish: port of tmux's automatic-rename. A pane's
# tab is renamed to the running program while it runs, and back to "fish"
# once it exits; a manual rename disables auto-rename for that tab, like
# tmux; the rename targets the pane's OWN tab by stable ID, so a command
# finishing in a background tab renames that tab, not the focused one.
#
#   T35_FISH_FILE=<path>   the zellij-tab-name.fish to test. Default: the repo's.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

FISH_FILE="${T35_FISH_FILE:-$REPO/fish/.config/fish/conf.d/zellij-tab-name.fish}"

if [ ! -f "$FISH_FILE" ]; then
  t_fail "zellij-tab-name.fish exists" "not found at $FISH_FILE"
  t_done
  exit $?
fi
if ! command -v fish >/dev/null 2>&1; then
  t_fail "fish installed" "fish not in PATH"
  t_done
  exit $?
fi
if ! command -v jq >/dev/null 2>&1; then
  t_fail "jq installed" "jq not in PATH"
  t_done
  exit $?
fi

zj_install_config
if ! zj_start; then
  t_done
  exit $?
fi

# A private XDG_RUNTIME_DIR so the auto-name state file never touches the
# real ${XDG_RUNTIME_DIR:-/tmp}/zellij-autoname/ (isolation, not the harness's
# already-private HOME).
T35_RUNTIME="$T_ROOT/runtime"
mkdir -p "$T35_RUNTIME"

# tab_name_at POS : name of the tab at 0-based POS (query-tab-names order).
tab_name_at() { zj_tabs | sed -n "$(($1 + 1))p"; }

# launch_fish : start fish, sourcing ONLY the file under test, in whichever
# pane is currently focused.
launch_fish() {
  zj_type "env XDG_RUNTIME_DIR='$T35_RUNTIME' fish --no-config -C 'source $FISH_FILE'"
  zj_enter
  sleep 1
}

launch_fish

# --- rename to the program, and back, across a run --------------------------
t35_tab0_is() { [ "$(tab_name_at 0)" = "$1" ]; }

zj_type 'sleep 2'; zj_enter
if wait_for 5 t35_tab0_is sleep; then
  t_ok "tab renamed to 'sleep' while the command runs"
else
  t_fail "tab renamed to 'sleep' while the command runs" "tab is [$(tab_name_at 0)]"
fi
if wait_for 5 t35_tab0_is fish; then
  t_ok "tab renamed back to 'fish' once the command exits"
else
  t_fail "tab renamed back to 'fish' once the command exits" "tab is [$(tab_name_at 0)]"
fi

# --- leading env assignments are skipped when picking the program name ------
zj_type 'env FOO=1 sleep 1'; zj_enter
if wait_for 5 t35_tab0_is sleep; then
  t_ok "'env FOO=1 sleep 1' still renames the tab to 'sleep'"
else
  t_fail "'env FOO=1 sleep 1' still renames the tab to 'sleep'" "tab is [$(tab_name_at 0)]"
fi
wait_for 5 t35_tab0_is fish

# --- a manual rename disables auto-rename for that tab, like tmux -----------
ZJ action rename-tab mytab >/dev/null 2>&1
wait_for 5 t35_tab0_is mytab
zj_type 'true'; zj_enter
sleep 1
assert_eq "manual rename survives a finished command" "$(tab_name_at 0)" mytab

zj_type 'sleep 1'; zj_enter
sleep 1.5
assert_eq "manual rename survives a command that would otherwise rename to 'sleep'" "$(tab_name_at 0)" mytab

# --- a command finishing in a background tab renames THAT tab ---------------
t35_tab_count_ge() { [ "$(zj_tab_count)" -ge "$1" ]; }

ZJ action new-tab >/dev/null 2>&1   # tab 1, auto-focused
if ! wait_for 5 t35_tab_count_ge 2; then
  t_fail "second tab is created" "$(zj_tabs)"
fi
launch_fish   # into the now-focused tab 1

t35_tab1_is() { [ "$(tab_name_at 1)" = "$1" ]; }
zj_type 'sleep 2'; zj_enter
if ! wait_for 5 t35_tab1_is sleep; then
  t_fail "background-tab setup: tab 1 shows 'sleep' before losing focus" "tab is [$(tab_name_at 1)]"
fi

ZJ action new-tab >/dev/null 2>&1   # tab 2, auto-focused: tab 1 is now the background tab
if ! wait_for 5 t35_tab_count_ge 3; then
  t_fail "third tab is created" "$(zj_tabs)"
fi

if wait_for 5 t35_tab1_is fish; then
  t_ok "the background tab (not the focused one) is renamed back to 'fish'"
else
  t_fail "the background tab (not the focused one) is renamed back to 'fish'" "tab 1 is [$(tab_name_at 1)]"
fi
focused_name="$(tab_name_at 2)"
assert_not_contains "the focused tab was left untouched by the background rename" "$focused_name" fish

# --- the shell prompt is not blocked waiting on the zellij calls -----------
# Back to tab 1's fish (still with the hook loaded), so the timing below
# actually exercises it rather than the plain shell in tab 2.
ZJ action go-to-tab 2 >/dev/null 2>&1
sleep 0.3
# Time the hooks themselves inside fish: preexec + postexec run on EVERY
# command, so any synchronous zellij/jq call is felt as input lag. fish
# cannot background a function or begin/end block (`&` on one still runs in
# the foreground), so this catches "looks async but isn't".
t35_hook_ms() { zj_pane_screen | sed -n 's/.*HOOKMS=\([0-9][0-9]*\).*/\1/p' | tail -1; }
# A zellij that takes 1s per call makes the difference unmistakable: in the
# foreground the two hooks cost >= 2s, in the background a few ms.
mkdir -p "$T_ROOT/slowbin"
printf '#!/bin/sh\nsleep 1\nexec %s "$@"\n' "$(command -v zellij)" >"$T_ROOT/slowbin/zellij"
chmod +x "$T_ROOT/slowbin/zellij"
# shellcheck disable=SC2016 # expanded by fish inside the pane
zj_type "set -lx PATH $T_ROOT/slowbin \$PATH; "'set -l t0 (date +%s%N); __zjautoname_preexec "sleep 1"; __zjautoname_postexec; set -l t1 (date +%s%N); echo HOOKMS=(math -s0 "($t1 - $t0) / 1000000")'; zj_enter
wait_for 8 sh -c "zellij --session '$ZJ_S' action dump-screen 2>/dev/null | grep -q 'HOOKMS=[0-9]'"
hook_ms="$(t35_hook_ms)"
if [ -n "$hook_ms" ] && [ "$hook_ms" -lt 300 ]; then
  t_ok "preexec+postexec do not wait for zellij (${hook_ms}ms with a 1s-per-call zellij)"
else
  t_fail "preexec+postexec do not wait for zellij" "took ${hook_ms:-?}ms with a 1s-per-call zellij"
fi

# Background renames race: for a quick command, "-> true" (preexec) and
# "-> fish" (postexec) start together. The later event must win no matter
# which worker finishes last. The slow zellij above makes both overlap.
t35_tab_at_is() { [ "$(zj_tabs | sed -n "$1p")" = "$2" ]; }
cur_pos=$(( $(zj_tab_pos) + 1 ))
zj_type 'true'; zj_enter
sleep 4
assert_eq "a quick command leaves the tab named fish (later rename wins)" "$(zj_tabs | sed -n "${cur_pos}p")" "fish"

t_check "session still alive" zj_ready

t_done
