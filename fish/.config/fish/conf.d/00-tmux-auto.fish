# Auto-attach tmux in Kitty only. Skip Cursor/IDE, SSH, already-in-tmux.
# NO_TMUX=1 opts out (kitty: Ctrl+Alt+N opens a plain window with it set).
# boot.sh creates the server AND restores the last resurrect snapshot (under
# flock) so `exec tmux attach` never fails and sessions survive reboots.
if status is-interactive
    and not set -q TMUX
    and not set -q NO_TMUX
    and set -q KITTY_WINDOW_ID
    and command -q tmux
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
