#!/usr/bin/env bash
# Cold boot must reattach the tmux session the user left, not the one
# resurrect happens to create last.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
BOOT="$REPO/tmux/.config/tmux/boot.sh"
REMEMBER_BIN="$REPO/tmux/.config/tmux/tmux-last-session.sh"
fail=0

ok() { printf 'ok  %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }

# shellcheck disable=SC1090
source "$BOOT"

tmp="$(mktemp -d)"
trap 'tmux -S "$tmp/sock" kill-server 2>/dev/null || true; rm -rf "$tmp"' EXIT
printf 'state\t\t\n' >"$tmp/empty-state.txt"
printf 'state\tjava\t\n' >"$tmp/java-state.txt"
printf 'dev-ops\n' >"$tmp/remember"

got="$(choose_boot_target "$tmp/remember" "$tmp/java-state.txt")"
[[ "$got" == "dev-ops" ]] && ok "remembered session wins over stale java state" || bad "remembered session wins (got ${got:-empty})"

: >"$tmp/remember"
got="$(choose_boot_target "$tmp/remember" "$tmp/java-state.txt")"
[[ "$got" == "java" ]] && ok "empty remember file falls back to snapshot" || bad "fallback (got ${got:-empty})"

got="$(choose_boot_target "$tmp/missing" "$tmp/empty-state.txt")"
[[ -z "$got" ]] && ok "empty state line is not a session name" || bad "empty state (got ${got:-empty})"

# Same creation order as a restore: dev-ops, frontend, home, java.
# With no -t, attach uses the most recently created session.
sock="$tmp/sock"
tmux -S "$sock" new-session -d -s dev-ops
tmux -S "$sock" new-session -d -s frontend
tmux -S "$sock" new-session -d -s home
tmux -S "$sock" new-session -d -s java

bare="$(python3 - "$sock" <<'PY'
import os, pty, sys, time, subprocess
sock = sys.argv[1]
_master, slave = pty.openpty()
proc = subprocess.Popen(
    ["tmux", "-S", sock, "attach"],
    stdin=slave, stdout=slave, stderr=slave, close_fds=True,
    env={**os.environ, "TERM": "xterm-256color"},
)
os.close(slave)
time.sleep(0.4)
name = subprocess.check_output(
    ["tmux", "-S", sock, "display-message", "-p", "#{client_session}"],
    text=True,
).strip()
subprocess.run(["tmux", "-S", sock, "detach-client"], check=False)
try:
    proc.wait(timeout=2)
except subprocess.TimeoutExpired:
    proc.kill()
print(name)
PY
)"
[[ "$bare" == "java" ]] && ok "bare attach lands on the last created session" || bad "bare attach (got ${bare:-empty})"

# Detach hook must record the session the client actually left.
export TMUX_LAST_SESSION_FILE="$tmp/hook-session"
tmux -S "$sock" set-hook -g client-detached \
  "run-shell -b 'TMUX_LAST_SESSION_FILE=$TMUX_LAST_SESSION_FILE $REMEMBER_BIN #{session_name}'"
python3 - "$sock" <<'PY'
import os, pty, sys, time, subprocess
sock = sys.argv[1]
_master, slave = pty.openpty()
proc = subprocess.Popen(
    ["tmux", "-S", sock, "attach", "-t", "dev-ops"],
    stdin=slave, stdout=slave, stderr=slave, close_fds=True,
    env={**os.environ, "TERM": "xterm-256color"},
)
os.close(slave)
time.sleep(0.4)
subprocess.run(["tmux", "-S", sock, "detach-client", "-s", "dev-ops"], check=False)
try:
    proc.wait(timeout=2)
except subprocess.TimeoutExpired:
    proc.kill()
time.sleep(0.3)
PY
hook_got="$(head -n 1 "$TMUX_LAST_SESSION_FILE" 2>/dev/null || true)"
[[ "$hook_got" == "dev-ops" ]] && ok "detach records dev-ops" || bad "detach hook (got ${hook_got:-empty})"

exit "$fail"
