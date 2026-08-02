# Terminal utils ported from Mac dots (yazi/tmux/fzf/zoxide/eza/starship)

# Default editor (yazi opener + CLI tools)
set -gx EDITOR nvim
set -gx VISUAL nvim

if status is-interactive
    # Smarter cd
    if command -q zoxide
        zoxide init fish | source
    end

    # fzf widgets; Ctrl-G = cd (Mac parity; default is Alt-C)
    if functions -q fzf_key_bindings
        fzf_key_bindings
        bind \cg fzf-cd-widget
        if bind --list-modes | string match -q insert
            bind -M insert \cg fzf-cd-widget
        end
    end

    # eza instead of ls
    if command -q eza
        alias ls 'eza --icons'
        alias ll 'eza -lah --icons'
        alias la 'eza -a --icons'
    end

    # Prompt
    if command -q starship
        starship init fish | source
    end
end
