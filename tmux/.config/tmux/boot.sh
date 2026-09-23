#!/usr/bin/env bash
# Ensure a tmux server exists, restoring the last resurrect snapshot first.
# Replaces continuum's auto-restore, which silently skips when any other tmux
# process is around at start (e.g. two Kittys) — autosave then overwrote `last`
# with an empty session. flock serialises concurrent Kitty windows.
set -uo pipefail

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

# Attach target = session that was focused when the snapshot was taken.
target="$(awk -F'\t' '$1=="state"{print $2; exit}' "$last" 2>/dev/null)"
if [[ -n "$target" ]] && tmux has-session -t "=$target" 2>/dev/null; then
  printf '%s\n' "$target" >"${XDG_RUNTIME_DIR:-/tmp}/tmux-boot-target"
else
  rm -f "${XDG_RUNTIME_DIR:-/tmp}/tmux-boot-target"
fi
exit 0
