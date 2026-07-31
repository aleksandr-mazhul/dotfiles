if status is-interactive
    fastfetch
    eval (keychain --eval -- ssh id_ed25519)
end
