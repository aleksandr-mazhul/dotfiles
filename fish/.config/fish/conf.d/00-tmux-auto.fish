# Auto-attach tmux in Kitty only. Skip Cursor/IDE, SSH, already-in-tmux.
# Check for a session BEFORE exec: `exec tmux attach` replaces fish, so if
# attach fails (no server / no session) Kitty's child dies and the window
# closes immediately — the `or new-session` never runs.
if status is-interactive
    and not set -q TMUX
    and set -q KITTY_WINDOW_ID
    and command -q tmux
    if tmux has-session 2>/dev/null
        exec tmux attach
    else
        exec tmux new-session
    end
end
