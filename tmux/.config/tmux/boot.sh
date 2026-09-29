#!/usr/bin/env bash
# Ensure a tmux server exists, restoring the last resurrect snapshot first.
# Replaces continuum's auto-restore, which silently skips when any other tmux
# process is around at start (e.g. two Kittys) — autosave then overwrote `last`
# with an empty session. flock serialises concurrent Kitty windows.
set -uo pipefail

# Session to attach after a cold restore. The resurrect `state` line is
# #{client_session}, which is empty when the save runs from client-detached
# (the client is already gone). Bare `tmux attach` then picks the session
# created last during restore — Java, not the one the user left.
choose_boot_target() {
  local remember="$1" snapshot="$2" target=""
  if [[ -r "$remember" ]]; then
    target="$(head -n 1 "$remember" | tr -d '\r')"
  fi
  if [[ -z "$target" && -e "$snapshot" ]]; then
    target="$(awk -F'\t' '$1=="state" && $2 != "" { print $2; exit }' "$snapshot" 2>/dev/null || true)"
  fi
  printf '%s\n' "$target"
}

boot_main() {
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/tmux-boot.lock"
flock 9

tmux has-session 2>/dev/null && exit 0

# Own scope, ordered Before=tmux-save.service, so on shutdown systemd runs the
# final save BEFORE it SIGTERMs the server: stop order is the reverse of start
# order, so the unit that starts first stops last. (After= here is the trap: it
# reads right but kills the server first -- verified with dummy units.) Started
# bare, the server lands in the launching Kitty's scope, which has no ordering
# against tmux-save.service: both stop in parallel and the save races a dying
# server. Pane scopes (tmux-spawn-*) are stopped before the server's scope by
# tmux itself, so the chain is: save -> server -> panes. Fallback: a bare
# server beats no server.
# 9>&- : the daemonised server must not inherit (and forever hold) the lock fd
systemd-run --user --scope --quiet --unit=tmux-server -p Before=tmux-save.service \
  tmux new-session -d -s 0 9>&- 2>/dev/null \
  || tmux has-session 2>/dev/null \
  || tmux new-session -d -s 0 9>&- || exit 0
restore="$HOME/.tmux/plugins/tmux-resurrect/scripts/restore.sh"
last="$HOME/.local/share/tmux/resurrect/last"
# run-shell (not a direct call): restore.sh derives the socket from $TMUX, which is empty outside tmux.
[[ -x "$restore" && -e "$last" ]] && tmux run-shell "$restore" >/dev/null 2>&1 9>&-

# Prefer the session recorded on switch/detach over resurrect's state line.
remember="${TMUX_LAST_SESSION_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/tmux/last-session}"
target="$(choose_boot_target "$remember" "$last")"
if [[ -n "$target" ]] && tmux has-session -t "=$target" 2>/dev/null; then
  printf '%s\n' "$target" >"${XDG_RUNTIME_DIR:-/tmp}/tmux-boot-target"
else
  rm -f "${XDG_RUNTIME_DIR:-/tmp}/tmux-boot-target"
fi
exit 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  boot_main "$@"
fi
