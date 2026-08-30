if status is-interactive
    # Keychain 3 --eval emits `set -x -U`, which writes SSH_AUTH_SOCK into
    # fish_variables. After reboot the socket file can still exist while the
    # agent is dead → "Connection refused" / ssh-add rc 2 on every terminal.
    # Keep env global-only and recycle a stale pidfile agent.
    if command -q keychain
        ssh-add -l >/dev/null 2>&1
        if test $status -gt 1
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
        keychain --quiet add --eval --quick --ignore-missing --systemd id_ed25519 \
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
