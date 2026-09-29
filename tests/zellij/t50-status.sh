#!/usr/bin/env bash
# Audit G: zjstatus renders a top status bar (PowerKit look) instead of the
# built-in tab-bar/status-bar, and reacts to tab changes live.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

# zs_row0 : the top screen row (chrome), plain text.
zs_row0() { zj_screen | sed -n '1p'; }
# zs_row0_ansi : the top screen row with ANSI codes intact, via tmux -e.
zs_row0_ansi() { TM capture-pane -p -e -t drv 2>/dev/null | sed -n '1p'; }
# zs_plugin_panes : one line per plugin pane "id<TAB>plugin_url".
zs_plugin_panes() {
  zj_panes_json | python3 -c '
import json, sys
try: panes = json.load(sys.stdin)
except Exception: sys.exit(0)
for p in panes:
    if p.get("is_plugin"):
        print("%s\t%s" % (p["id"], p.get("plugin_url") or ""))'
}

zj_install_config
zj_need_plugins zjstatus vim-zellij-navigator || { t_done; exit $?; }

if ! zj_start; then
  t_done
  exit $?
fi

sleep 0.5

plugins_before="$(zs_plugin_panes)"

# G: no built-in tab-bar/status-bar, exactly a zjstatus plugin pane instead.
assert_not_contains "no builtin tab-bar plugin pane (G)" "$plugins_before" $'\ttab-bar'
assert_not_contains "no builtin status-bar plugin pane (G)" "$plugins_before" $'\tstatus-bar'
assert_contains "a zjstatus plugin pane exists (C3/G)" "$plugins_before" "zjstatus.wasm"

# G: no floating tips/release-notes panes over the first pane.
floating="$(zj_panes_json | python3 -c '
import json, sys
try: panes = json.load(sys.stdin)
except Exception: sys.exit(0)
print(sum(1 for p in panes if p.get("is_floating")))')"
assert_eq "no floating tips/release-notes panes (G)" "${floating:-?}" "0"

# G: bar is row 0 and shows the active tab's index and name.
row0="$(zs_row0)"
assert_contains "row 0 shows active tab index 1 (G)" "$row0" "1"
assert_contains "row 0 shows the default tab name (G)" "$row0" "Tab #1"

# G: active tab pill uses the chrome highlight color (best-effort: only
# asserted when the ANSI dump actually carries truecolor SGR codes).
ansi0="$(zs_row0_ansi)"
if printf '%s' "$ansi0" | grep -qE '\[48;2;[0-9]+;[0-9]+;[0-9]+m'; then
  hi_hex="$(grep -oE '\[chrome-highlight-bg\]="#[0-9a-fA-F]{6}"' "$XDG_CONFIG_HOME/tmux/theme-status.sh" 2>/dev/null | grep -oE '#[0-9a-fA-F]{6}')"
  if [ -n "$hi_hex" ]; then
    r=$((16#${hi_hex:1:2})); g=$((16#${hi_hex:3:2})); b=$((16#${hi_hex:5:2}))
    assert_contains "active tab pill uses chrome-highlight-bg $hi_hex (G)" "$ansi0" "[48;2;${r};${g};${b}m"
  else
    t_skip "active tab pill uses chrome highlight color" "no rendered tmux theme to read chrome-highlight-bg from"
  fi
else
  t_skip "active tab pill uses chrome highlight color" "no truecolor SGR in captured ANSI"
fi

# G: after new-tab the bar shows both tabs.
zs_has_tab2() { zj_tabs | grep -q "Tab #2"; }
zs_bar_has_tab2() { zs_row0 | grep -q "2"; }
ZJ action new-tab >/dev/null 2>&1
wait_for 10 zs_has_tab2
wait_for 10 zs_bar_has_tab2
row0_two="$(zs_row0)"
assert_contains "after new-tab, bar shows tab 1 (G)" "$row0_two" "1"
assert_contains "after new-tab, bar shows tab 2 (G)" "$row0_two" "2"
assert_contains "after new-tab, bar still shows Tab #1 (G)" "$row0_two" "Tab #1"
assert_contains "after new-tab, bar shows Tab #2 (G)" "$row0_two" "Tab #2"

# G: after rename-tab the bar shows the new name.
zs_bar_has_work() { zs_row0 | grep -q "work"; }
ZJ action rename-tab "work" >/dev/null 2>&1
wait_for 10 zs_bar_has_work
row0_renamed="$(zs_row0)"
assert_contains "after rename-tab, bar shows the new tab name (G)" "$row0_renamed" "work"
assert_not_contains "after rename-tab, bar no longer shows the old name (G)" "$row0_renamed" "Tab #2"

t_check "session still alive" zj_ready

t_done
