# Persistent fish command history (shared across tmux panes/sessions)
# Ownership of ~/.local/share/fish must be the user (not root).
if status is-interactive
    # Merge history from other sessions so Up-arrow sees recent commands
    history merge 2>/dev/null
end
