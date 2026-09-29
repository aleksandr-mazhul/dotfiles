# Auto-attach a terminal multiplexer in Kitty only. Skip Cursor/IDE, SSH,
# already-in-a-mux. NO_TMUX=1 opts out (kitty: Ctrl+Alt+N opens a plain
# window with it set); NO_MUX=1 is the mux-agnostic spelling of the same
# thing, kept alongside it during the migration.
#
# MUX switch: tmux stays the default (unset MUX, or MUX=tmux) until the
# zellij side of the migration is cut over; MUX=zellij routes through
# zellij-boot instead. Delete the tmux branch in a separate commit once
# zellij is the only path.
if status is-interactive
    and not set -q TMUX
    and not set -q ZELLIJ
    and not set -q NO_MUX
    and not set -q NO_TMUX
    and set -q KITTY_WINDOW_ID

    if set -q MUX; and test "$MUX" = zellij
        exec zellij-boot
    else if command -q tmux
        # boot.sh creates the server AND restores the last resurrect snapshot
        # (under flock) so `exec tmux attach` never fails and sessions survive reboots.
        ~/.config/tmux/boot.sh
        set -l target
        if test -r $XDG_RUNTIME_DIR/tmux-boot-target
            set target (cat $XDG_RUNTIME_DIR/tmux-boot-target)
            rm -f $XDG_RUNTIME_DIR/tmux-boot-target  # one-shot: only the boot attach
        end
        if test -n "$target"; and tmux has-session -t "=$target" 2>/dev/null
            exec tmux attach -t "=$target"
        else if tmux has-session 2>/dev/null
            exec tmux attach
        else
            exec tmux new-session
        end
    end
end
