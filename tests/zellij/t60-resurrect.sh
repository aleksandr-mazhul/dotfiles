#!/usr/bin/env bash
# Resurrect filtering (contract a) + end-to-end zellij-boot resurrection
# (contract b), see docs/zellij-migration.
#
#   T60_BIN_DIR=<dir>   directory holding zellij-resurrect-filter and
#                        zellij-boot (they must be siblings there).
#                        Default: the repo's bin/.local/bin.
# shellcheck source=tests/zellij/lib.sh
source "$(dirname "$0")/lib.sh"

BIN_DIR="${T60_BIN_DIR:-$REPO/bin/.local/bin}"
FILTER="$BIN_DIR/zellij-resurrect-filter"
BOOT="$BIN_DIR/zellij-boot"
FIXTURES="$(dirname "$0")/fixtures"

# t60_kdl_command NAME FILE : the value of the first pane's command="..."
# attribute whose header also contains NAME (used to sanity check a block).
t60_pane_block() {
  # Print the "pane command=\"$1\" ..." block (header through matching close)
  # for the Nth (1-based, $2) occurrence in $3.
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys
want, nth, path = sys.argv[1], int(sys.argv[2]), sys.argv[3]
lines = open(path, encoding="utf-8").read().splitlines()
count = 0
i = 0
while i < len(lines):
    m = re.match(r'^(\s*)pane\b.*command="%s"' % re.escape(want), lines[i])
    if m:
        count += 1
        if count == nth:
            indent = m.group(1)
            out = [lines[i]]
            if lines[i].rstrip().endswith('{'):
                depth = 1
                j = i + 1
                while j < len(lines) and depth > 0:
                    depth += lines[j].count('{') - lines[j].count('}')
                    out.append(lines[j])
                    j += 1
            print('\n'.join(out))
            sys.exit(0)
    i += 1
sys.exit(1)
PY
}

# --- unit tests: filter on the fixture (unit tests of contract a) ------------

if [ ! -x "$FILTER" ]; then
  t_fail "zellij-resurrect-filter exists and is executable" "not found at $FILTER"
else
  WORK="$T_ROOT/unit-1.kdl"
  cp "$FIXTURES/t60-session-layout.kdl" "$WORK"
  t_check "filter runs in place on a real captured layout" "$FILTER" "$WORK"

  npm_block="$(t60_pane_block npm 1 "$WORK")"
  assert_contains 'B4/H4-npm: "npm run dev" kept as-is (args unchanged)' "$npm_block" 'args "run" "dev"'
  assert_not_contains 'B4/H4-npm: start_suspended dropped from the kept npm pane' "$npm_block" "start_suspended"

  claude1_block="$(t60_pane_block claude 1 "$WORK")"
  assert_contains 'H4-claude (no orig args): waits for VPN then --continue' "$claude1_block" 'args "claude" "--continue"'
  assert_contains 'H4-claude (no orig args): command is the VPN waiter' "$claude1_block" 'command="vpn-wait-exec"'
  assert_not_contains 'H4-claude (no orig args): start_suspended dropped' "$claude1_block" "start_suspended"

  claude2_block="$(t60_pane_block claude 2 "$WORK")"
  assert_contains 'H4-claude (orig --resume x): waits for VPN then --continue' "$claude2_block" 'args "claude" "--continue"'
  assert_not_contains 'H4-claude (orig --resume x): start_suspended dropped' "$claude2_block" "start_suspended"

  if grep -q 'command="sleep"' "$WORK"; then
    t_fail "H4-other: sleep pane's command attribute is dropped"
  else
    t_ok "H4-other: sleep pane's command attribute is dropped"
  fi
  assert_not_contains "H4-other: sleep pane's args are dropped" "$(cat "$WORK")" '"999"'
  # Structural bits survive the conversion to a plain shell pane.
  assert_contains "H4-other: plain pane keeps focus=true / size" "$(cat "$WORK")" 'pane focus=true size="33%"'

  # Untouched machinery: tabs/plugins/floating-panes/swap-layouts survive byte-for-byte.
  orig_tail="$(sed -n '/new_tab_template/,$p' "$FIXTURES/t60-session-layout.kdl")"
  new_tail="$(sed -n '/new_tab_template/,$p' "$WORK")"
  assert_eq "everything after the tab (swap layouts, floating panes) is untouched" "$new_tail" "$orig_tail"

  # Idempotency: filtering an already-filtered file changes nothing further.
  cp "$WORK" "$T_ROOT/unit-1-again.kdl"
  "$FILTER" "$T_ROOT/unit-1-again.kdl"
  if diff -q "$WORK" "$T_ROOT/unit-1-again.kdl" >/dev/null; then
    t_ok "filter is idempotent (second pass changes nothing)"
  else
    t_fail "filter is idempotent (second pass changes nothing)" "$(diff "$WORK" "$T_ROOT/unit-1-again.kdl" | head -10)"
  fi

  # Real npm retitles itself, so zellij serializes it as ONE string
  # (command="npm run dev", no args node). Other commands keep their cwd.
  real_out="$("$FILTER" - <"$FIXTURES/t60-real-forms.kdl")"
  assert_contains 'H4-npm real form: command="npm run dev" kept' "$real_out" 'pane command="npm run dev" size="50%"'
  assert_not_contains 'H4 real form: start_suspended dropped everywhere' "$real_out" 'start_suspended'
  assert_not_contains 'H4-other real form: python3 command dropped' "$real_out" 'python3'
  assert_contains 'H4-other real form: plain pane keeps its cwd' "$real_out" 'cwd="/srv/app"'
  assert_contains 'H4-claude real form: bare claude waits for VPN' "$real_out" 'args "claude" "--continue"'
  assert_contains 'H4-npm real form: absolute-path npm kept' "$real_out" 'pane command="/usr/bin/npm run build"'
  assert_contains 'H4-claude real form: absolute-path claude waits for VPN' \
    "$real_out" 'args "/home/stranger/.local/bin/claude" "--continue"'
  assert_eq 'H4-claude real form: both claude panes use the VPN waiter' \
    "$(printf '%s\n' "$real_out" | grep -c 'command="vpn-wait-exec"')" "2"

  # "-" filters stdin to stdout without touching any file.
  stdout_result="$("$FILTER" - <"$FIXTURES/t60-session-layout.kdl")"
  if [ "$stdout_result" = "$(cat "$WORK")" ]; then
    t_ok "'-' filters stdin to stdout, matching the in-place result"
  else
    t_fail "'-' filters stdin to stdout, matching the in-place result"
  fi

  # Quote-aware command removal: command="..." values containing spaces or
  # escaped quotes must not corrupt the KDL when the attribute is dropped --
  # a \S+ tokenizer splits inside the quoted value (e.g. command="yarn dev"
  # -> leftover `dev" size=...`), producing invalid KDL.
  quoted_content="$("$FILTER" - <"$FIXTURES/t60-quoted-cmds.kdl")"
  assert_not_contains "quoted cmds: no command= attribute survives" "$quoted_content" 'command='
  assert_not_contains "quoted cmds: start_suspended dropped" "$quoted_content" 'start_suspended'
  assert_not_contains "quoted cmds: no leftover fragment from command=\"yarn dev\"" "$quoted_content" 'dev"'
  assert_not_contains "quoted cmds: no leftover fragment from command=\"python3 manage.py runserver\"" "$quoted_content" 'runserver"'
  assert_not_contains "quoted cmds: no leftover fragment from the escaped-quote command" "$quoted_content" 'echo'
  assert_contains "quoted cmds: command=\"yarn dev\" header becomes exactly the plain-pane form" "$quoted_content" 'pane size="31%" {'
  assert_contains "quoted cmds: command=\"python3 manage.py runserver\" header becomes exactly the plain-pane form" "$quoted_content" 'pane size="32%" {'
  assert_contains "quoted cmds: escaped-quote command header becomes exactly the plain-pane form (focus kept)" "$quoted_content" 'pane focus=true size="33%" {'

  # The filtered file must still be a loadable zellij layout: dropping
  # command="a b" or an escaped-quote command cannot leave invalid KDL that
  # fails resurrection under `zellij attach --force-run-commands`.
  if ! command -v zellij >/dev/null 2>&1; then
    t_skip "filtered quoted-cmds layout parses and loads" "zellij not in PATH"
  else
    quoted_layout="$T_ROOT/t60-quoted-filtered.kdl"
    printf '%s\n' "$quoted_content" >"$quoted_layout"
    QUOTED_SESSION="${ZJ_S}q"
    TM new-session -d -s drvq -x 200 -y 50 \
      "zellij --session '$QUOTED_SESSION' --new-session-with-layout '$quoted_layout'; echo ZELLIJ_EXITED \$?; sleep 5"
    if wait_for 8 zellij --session "$QUOTED_SESSION" action query-tab-names; then
      t_ok "filtered quoted-cmds layout parses and loads (quote-aware removal keeps valid KDL)"
    else
      t_fail "filtered quoted-cmds layout parses and loads (quote-aware removal keeps valid KDL)" \
        "$(TM capture-pane -p -t drvq 2>/dev/null | head -20)"
    fi
    zellij kill-session "$QUOTED_SESSION" >/dev/null 2>&1
    TM kill-session -t drvq >/dev/null 2>&1
  fi
fi

# --- end-to-end: a real dead session gets resurrected correctly --------------

t60_have_fakebin=1
if ! command -v cc >/dev/null 2>&1; then
  t_skip "end-to-end resurrection" "no C compiler (cc) available to build fake claude/npm"
  t60_have_fakebin=0
fi

if [ "$t60_have_fakebin" -eq 1 ] && { [ ! -x "$FILTER" ] || [ ! -x "$BOOT" ]; }; then
  t_fail "zellij-boot exists and is executable" "not found at $BOOT (or filter missing) -- skipping end-to-end"
  t60_have_fakebin=0
fi

if [ "$t60_have_fakebin" -eq 1 ]; then
  # A real ELF binary (not a #!-script) so argv[0] survives as typed, exactly
  # like the real `claude`/`npm` binaries do on this machine (see fixtures'
  # provenance note). It records its own argv then sleeps.
  cat >"$T_ROOT/fakebin.c" <<'CEOF'
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <libgen.h>
#include <string.h>
int main(int argc, char **argv) {
    const char *dir = getenv("T60_LOG_DIR");
    if (dir) {
        char base[256];
        strncpy(base, argv[0], sizeof(base) - 1);
        base[sizeof(base) - 1] = 0;
        char path[1024];
        snprintf(path, sizeof(path), "%s/%s.log", dir, basename(base));
        FILE *f = fopen(path, "a");
        if (f) {
            for (int i = 0; i < argc; i++) fprintf(f, "%s%s", i ? " " : "", argv[i]);
            fprintf(f, "\n");
            fclose(f);
        }
    }
    sleep(999);
    return 0;
}
CEOF
  if ! cc -O2 -o "$T_ROOT/fakebin" "$T_ROOT/fakebin.c" 2>"$T_ROOT/cc.err"; then
    t_fail "building the fake claude/npm ELF helper" "$(cat "$T_ROOT/cc.err")"
    t60_have_fakebin=0
  fi
fi

if [ "$t60_have_fakebin" -eq 1 ]; then
  mkdir -p "$HOME/bin" "$T_ROOT/logs"
  cp "$T_ROOT/fakebin" "$HOME/bin/claude"
  cp "$T_ROOT/fakebin" "$HOME/bin/npm"
  export T60_LOG_DIR="$T_ROOT/logs"
  export PATH="$HOME/bin:$PATH"

  zj_install_config
  # t60 only exercises the resurrect bin/ contract, not the config/layout/
  # theme contract (t00's job); write just enough to avoid the first-run
  # wizard and enable resurrection.
  cat >"$XDG_CONFIG_HOME/zellij/config.kdl" <<'EOF'
show_startup_tips false
show_release_notes false
session_serialization true
serialize_pane_viewport true
EOF

  if zj_start; then
    zj_type 'npm run dev'; zj_enter
    wait_for 5 test -s "$T_ROOT/logs/npm.log"
    ZJ action new-pane; sleep 0.3
    zj_type 'claude'; zj_enter
    wait_for 5 grep -q '^claude$' "$T_ROOT/logs/claude.log"
    ZJ action new-pane; sleep 0.3
    zj_type 'claude --resume x'; zj_enter
    wait_for 5 grep -q 'claude --resume x' "$T_ROOT/logs/claude.log"
    ZJ action new-pane; sleep 0.3
    zj_type 'sleep 999'; zj_enter
    sleep 0.5

    npm_before="$(wc -l <"$T_ROOT/logs/npm.log")"
    claude_before="$(wc -l <"$T_ROOT/logs/claude.log")"

    ZJ action save-session >/dev/null 2>&1
    wait_for 5 test -f "$XDG_CACHE_HOME/zellij/contract_version_1/session_info/$ZJ_S/session-layout.kdl"
    sleep 0.5

    zellij kill-session "$ZJ_S" >/dev/null 2>&1
    if wait_for 10 sh -c "zellij list-sessions --no-formatting 2>/dev/null | grep -q '^$ZJ_S .*EXITED'"; then
      t_ok "killed session shows as EXITED/resurrectable"
    else
      t_fail "killed session shows as EXITED/resurrectable"
    fi

    TM new-window -t drv -n boot "'$BOOT'; echo T60_BOOT_EXITED \$?; sleep 30" >/dev/null 2>&1

    if wait_for 15 sh -c "[ \"\$(wc -l <'$T_ROOT/logs/claude.log')\" -gt $claude_before ]"; then
      t_ok "B18/H4 both claude panes are running again after resurrection"
    else
      t_fail "B18/H4 both claude panes are running again after resurrection" "$(cat "$T_ROOT/logs/claude.log")"
    fi
    claude_tail="$(tail -n 2 "$T_ROOT/logs/claude.log")"
    assert_eq "H4 both resurrected claude panes ran with exactly --continue" \
      "$claude_tail" "$(printf 'claude --continue\nclaude --continue')"

    if wait_for 15 sh -c "[ \"\$(wc -l <'$T_ROOT/logs/npm.log')\" -gt $npm_before ]"; then
      t_ok "H4-npm the npm pane runs again without waiting for Enter (not suspended)"
    else
      t_fail "H4-npm the npm pane runs again without waiting for Enter (not suspended)" "$(cat "$T_ROOT/logs/npm.log")"
    fi
    assert_eq "H4-npm resurrected npm pane still runs exactly npm run dev" \
      "$(tail -n 1 "$T_ROOT/logs/npm.log")" "npm run dev"

    sleep 1
    panes_after="$(zj_panes)"
    sleep_cmd="$(printf '%s\n' "$panes_after" | awk -F'\t' '$11==""{print; exit}')"
    if [ -n "$sleep_cmd" ]; then
      t_ok "H4-other the sleep pane resurrects as a plain shell (no auto-run command)"
    else
      t_fail "H4-other the sleep pane resurrects as a plain shell (no auto-run command)" "$panes_after"
    fi
  fi
fi

t_done
