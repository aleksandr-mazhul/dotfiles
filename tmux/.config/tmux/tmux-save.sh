#!/usr/bin/env bash
# Coalescing wrapper around tmux-resurrect's save.sh.
#
#   tmux-save.sh request   from tmux hooks; returns in ~4 ms, coalesces bursts
#   tmux-save.sh now       save as soon as the lock is free (detach / manual)
#   tmux-save.sh quiet     what continuum passes via @resurrect-save-script-path,
#                          so the periodic tick shares this lock too
#
# EVERY save must go through here. Two resurrect bugs make that mandatory; both
# were reproduced on tmux 3.7c / resurrect cff343c:
#
#   1. save.sh takes no lock at all. Two overlapping saves append into the same
#      state file and stage into the same pane_contents/ dir, which each one rm's
#      at the end -> duplicated `pane` lines, 3 `state` lines, truncated tar.gz.
#
#   2. Worse, and silent: save.sh names its output from `date +%Y%m%dT%H%M%S`,
#      i.e. 1-second granularity. Two saves in the SAME SECOND write the same
#      path, then files_differ compares that file against `last` -- a symlink to
#      that same inode -- decides "unchanged" and rm's it. `last` is left
#      dangling, boot.sh's `-e "$last"` guard fails, and the restore is skipped
#      in silence. Hence the >=1s floor and the self-heal below.
#
# Debug: TMUX_SAVE_LOG=/path/to/log to trace decisions.
set -uo pipefail

DEBOUNCE="${TMUX_SAVE_DEBOUNCE:-4}"   # quiet seconds before a save
MAXWAIT="${TMUX_SAVE_MAXWAIT:-30}"    # force a save after this much nonstop churn
INHIBIT_TTL=300                       # a forgotten restore-inhibit expires

RUN="${XDG_RUNTIME_DIR:-/tmp}/tmux-save-$(id -u)"
STAMP="$RUN/dirty"
WORKER_LOCK="$RUN/worker.lock"
SAVE_LOCK="$RUN/save.lock"
LASTRUN="$RUN/lastrun"
INHIBIT="$RUN/inhibit"

SAVE="$HOME/.tmux/plugins/tmux-resurrect/scripts/save.sh"
SELF="$(readlink -f "${BASH_SOURCE[0]}")"

mkdir -p "$RUN" 2>/dev/null || exit 0
[ -x "$SAVE" ] || exit 0
command -v tmux >/dev/null || exit 0

log() { [ -n "${TMUX_SAVE_LOG:-}" ] && printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >>"$TMUX_SAVE_LOG"; return 0; }
mtime() { stat -c %Y "$1" 2>/dev/null || echo 0; }

inhibited() {
  [ -e "$INHIBIT" ] || return 1
  if [ $(( $(date +%s) - $(mtime "$INHIBIT") )) -gt "$INHIBIT_TTL" ]; then
    rm -f "$INHIBIT"; return 1
  fi
  return 0
}

# No eval here: expand a leading ~ by hand rather than executing an option value.
resurrect_dir() {
  local d
  d="$(tmux show-option -gqv @resurrect-dir 2>/dev/null)"
  [ -n "$d" ] || d="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
  case "$d" in
    "~") d="$HOME" ;;
    "~/"*) d="$HOME/${d#\~/}" ;;
  esac
  printf '%s' "$d"
}

do_save() {
  exec 9>"$SAVE_LOCK"
  flock -w 120 9 || { log "lock timeout"; return 0; }
  inhibited && { log "inhibited (restore in flight)"; return 0; }

  # Shutdown guard: never replace a good snapshot with a dead or empty server.
  local panes
  panes="$(tmux list-panes -a -F x 2>/dev/null | wc -l)"
  [ "${panes:-0}" -ge 1 ] || { log "skip: no panes (server gone?)"; return 0; }

  # Bug 2 floor: never two saves inside one wall-clock second.
  [ "$(date +%s)" -le "$(cat "$LASTRUN" 2>/dev/null || echo 0)" ] && sleep 1

  "$SAVE" quiet >/dev/null 2>&1
  date +%s >"$LASTRUN"
  log "saved ($panes panes)"

  # Self-heal: if `last` is dangling anyway, redo it a second later.
  local last
  last="$(resurrect_dir)/last"
  if [ -L "$last" ] && [ ! -e "$last" ]; then
    log "last was dangling -- re-saving"
    sleep 1
    "$SAVE" quiet >/dev/null 2>&1
    date +%s >"$LASTRUN"
  fi
}

request() {
  inhibited && exit 0
  : >"$STAMP"
  setsid -f "$SELF" worker </dev/null >/dev/null 2>&1
  exit 0
}

case "${1:-request}" in
  now)
    inhibited && exit 0
    setsid -f "$SELF" worker-now </dev/null >/dev/null 2>&1
    ;;
  worker-now) do_save ;;
  worker)
    exec 8>"$WORKER_LOCK"
    flock -n 8 || exit 0          # a worker is already pending; it will see our stamp
    deadline=$(( $(date +%s) + MAXWAIT ))
    while :; do
      seen="$(mtime "$STAMP")"
      sleep "$DEBOUNCE"
      inhibited && exit 0
      [ "$(mtime "$STAMP")" = "$seen" ] && break
      [ "$(date +%s)" -ge "$deadline" ] && { log "maxwait hit"; break; }
    done
    # Release before saving: a request that lands mid-save must be able to
    # start the next worker, or that change waits for the next continuum tick.
    exec 8>&-
    do_save
    ;;
  *) request ;;
esac
exit 0
