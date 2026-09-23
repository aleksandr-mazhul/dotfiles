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

        # Keep the selected history entry readable against fzf's highlight.
        function fzf-history-widget -d "Show command history"
            set -l command_line (commandline)
            set -l current_line (commandline -L)
            set -l total_lines (count $command_line)
            set -l fzf_query (string escape -- $command_line[$current_line])
            set -lx FZF_DEFAULT_COMMAND \
                'builtin history -z --show-time=(set_color $fish_color_comment 2>/dev/null; or set_color normal)"%F %a %T%t%s%t"(set_color normal)'
            set -lx FZF_DEFAULT_OPTS (__fzf_defaults '' \
                '--with-nth=2.. --nth=2..,.. --scheme=history --multi --no-multi-line' \
                '--no-wrap --wrap-sign="\t\t\t↳ " --preview-wrap-sign="↳ " --freeze-left=1' \
                '--bind="ctrl-r:toggle-sort,alt-r:toggle-raw" --highlight-line' \
                '--accept-nth=3.. --delimiter="\t" --tabstop=4 --read0 --print0' \
                '--color=fg+:#1a1008,bg+:#ffb688,hl+:#1a1008')
            set -lx FZF_DEFAULT_OPTS_FILE
            test -z "$fish_private_mode"; and builtin history merge
            if set -l result (eval $FZF_DEFAULT_COMMAND \| (__fzfcmd) --query=$fzf_query | string split0)
                if test "$total_lines" -eq 1
                    commandline -- $result
                else
                    set -l a (math $current_line - 1)
                    set -l b (math $current_line + 1)
                    commandline -- $command_line[1..$a] $result $command_line[$b..-1]
                end
            end
            commandline -f repaint
        end
        bind \cr fzf-history-widget
        if bind --list-modes | string match -q insert
            bind -M insert \cr fzf-history-widget
        end
    end

    # Always show hidden files (dotfiles) in listings + fzf/fd
    if command -q eza
        set -gx EZA_COLORS 'lc=0:lm=0'
        alias ls 'eza -a --icons=auto --links'
        alias ll 'eza -lah --icons=auto --links'
        alias la 'eza -lah --icons=auto --links'
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
