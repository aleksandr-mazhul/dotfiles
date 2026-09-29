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

        # --highlight-line keeps the selected entry readable; its fg+/bg+ come
        # from the theme-generated FZF_DEFAULT_OPTS (theme-fzf.fish).
        # The frozen column is the command time (%F %T), not the raw epoch.
        # A fixed hue cannot be readable on both the dark row and the peach
        # current line, and fzf will not replace an explicit SGR foreground
        # there (fish_color_comment stayed salmon on peach). Instead the time
        # is the non-nth part: fg:dim quiets it, nth:regular keeps the command
        # at full fg, and fg+:regular drops that dim on the current line so
        # the time becomes the same dark ink as the command. --nth is only the
        # command; including the whole line would clear the dim. The epoch
        # remains the hidden middle field, so accept-nth=3.. is still the command.
        # --ansi asks fzf to drop SGR on accept. The fish strip is the
        # guarantee: a recalled command, and the next search query, never
        # start with a reset (kitty would draw it as "␛[m").
        function fzf-history-widget -d "Show command history"
            set -l command_line (commandline)
            set -l current_line (commandline -L)
            set -l total_lines (count $command_line)
            set -l raw_query $command_line[$current_line]
            set -l stripped_query (string replace -ra '\e\[[0-9;]*m' '' -- $raw_query)
            and set raw_query $stripped_query
            set -l fzf_query (string escape -- $raw_query)
            set -lx FZF_DEFAULT_COMMAND \
                'builtin history -z --show-time="%F %T%t%s%t"'
            set -lx FZF_DEFAULT_OPTS (__fzf_defaults '' \
                '--with-nth=1,3.. --nth=2.. --scheme=history --multi --no-multi-line' \
                '--color=fg:dim,nth:regular,fg+:regular' \
                '--no-wrap --wrap-sign="\t\t\t↳ " --preview-wrap-sign="↳ " --freeze-left=1' \
                '--bind="ctrl-r:toggle-sort,alt-r:toggle-raw" --highlight-line' \
                '--accept-nth=3.. --delimiter="\t" --tabstop=4 --ansi --read0 --print0')
            set -lx FZF_DEFAULT_OPTS_FILE
            test -z "$fish_private_mode"; and builtin history merge
            if set -l result (eval $FZF_DEFAULT_COMMAND \| (__fzfcmd) --query=$fzf_query | string split0)
                set -l stripped (string replace -ra '\e\[[0-9;]*m' '' -- $result)
                and set result $stripped
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
