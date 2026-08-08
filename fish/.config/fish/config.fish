if status is-interactive
    # Quiet SSH agent (Keychain 3.x — do NOT pass "ssh" as a key name)
    keychain --quiet add --eval --quick --ignore-missing id_ed25519 | source

    # System info with readable colors (set in fastfetch config)
    fastfetch
end

# No "Welcome to fish…" spam
set -g fish_greeting


# User-local bins (theme-*, zen-browser, …)
fish_add_path -g "$HOME/.local/bin"
