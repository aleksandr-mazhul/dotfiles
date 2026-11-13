
# uv's installer writes this beside its binary. The NixOS package is already on PATH.
if test -f "$HOME/.local/share/../bin/env.fish"
    source "$HOME/.local/share/../bin/env.fish"
end
