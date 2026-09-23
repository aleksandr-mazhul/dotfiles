if status is-interactive
    # Keychain 3 --eval emits `set -x -U`, which writes SSH_AUTH_SOCK into
    # fish_variables. After reboot the socket file can still exist while the
    # agent is dead → "Connection refused" / ssh-add rc 2 on every terminal.
    # Keep env global-only and recycle a stale pidfile agent.
    # Fast path: an agent that already holds a key needs nothing from keychain
    # (163 of fish's 189 ms startup). ssh-add -l: 0 = keys, 1 = none, 2 = dead.
    ssh-add -l >/dev/null 2>&1
    set -l agent_status $status
    if test $agent_status -ne 0; and command -q keychain
        if test $agent_status -gt 1
            set -e SSH_AUTH_SOCK SSH_AGENT_PID
            set -Ue SSH_AUTH_SOCK 2>/dev/null
            set -Ue SSH_AGENT_PID 2>/dev/null
            set -l kc_sh $HOME/.keychain/*-sh
            if test -f "$kc_sh"
                set -l kc_pid (string match -rg 'SSH_AGENT_PID=(\d+)' < $kc_sh)
                if test -n "$kc_pid"; and not test -d /proc/$kc_pid
                    keychain --quiet agent stop >/dev/null 2>&1
                end
            end
        end
        # keychain picks the --eval syntax from $SHELL; fish started from a
        # bash-parented process (IDE, agent, script) would get sh syntax.
        SHELL=(status fish-path) keychain --quiet add --eval --quick --ignore-missing --systemd id_ed25519 \
            | string replace -a -- ' -U ' ' -g ' \
            | source
    end

    # System info with readable colors (set in fastfetch config)
    fastfetch
end

# No "Welcome to fish…" spam
set -g fish_greeting


# User-local bins (theme-*, zen-browser, …)
fish_add_path -g "$HOME/.local/bin"
# npm global prefix (claude — the native updater gets 403, so it is installed via npm)
fish_add_path -g "$HOME/.npm-global/bin"
