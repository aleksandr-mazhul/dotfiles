# Terminal utils — modifiers via own configs only (kanata untouched).
# HRM D-finger = Ctrl → use Ctrl for app chords; Super for clear screen.

set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    if command -q zoxide
        zoxide init fish | source
    end

    # Super+L = clear screen (Ctrl+L is window-focus in nvim / not clear here)
    # Kitty also maps super+l → clear_terminal as a reliable fallback.
    bind \e\[108\;9u 'clear; commandline -f repaint' 2>/dev/null
    if bind --list-modes | string match -q insert
        bind -M insert \e\[108\;9u 'clear; commandline -f repaint' 2>/dev/null
    end

    # fzf: Ctrl-G = cd (D-finger)
    if functions -q fzf_key_bindings
        fzf_key_bindings
        bind \cg fzf-cd-widget
        if bind --list-modes | string match -q insert
            bind -M insert \cg fzf-cd-widget
        end
    end

    # Always show hidden files (dotfiles) in listings + fzf/fd
    if command -q eza
        alias ls 'eza -a --icons'
        alias ll 'eza -lah --icons'
        alias la 'eza -lah --icons'
    else
        alias ls 'ls -A --color=auto'
        alias ll 'ls -lah --color=auto'
        alias la 'ls -lah --color=auto'
    end
    if command -q fd
        set -gx FZF_DEFAULT_COMMAND 'fd --hidden --follow --exclude .git'
        set -gx FZF_CTRL_T_COMMAND $FZF_DEFAULT_COMMAND
        set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --follow --exclude .git'
    end

    if command -q starship
        starship init fish | source
    end
end
