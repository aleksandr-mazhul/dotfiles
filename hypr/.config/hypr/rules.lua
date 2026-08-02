hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Rice quickshell panels: Hyprland layer fade + size tween looks jerky on open/expand.
hl.layer_rule({
    name = "rice-no-anim",
    match = { namespace = "^rice-" },
    no_anim = true,
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name = "clipboard-ui-float",
    match = { class = "com.hypr.clipboardhistory" },
    float = true,
    pin = true,
    center = true,
    opacity = "1.0 override",
})

-- =============================================================================
-- App → workspace (ported from macos yabai scripts/rules.sh + spaces.sh)
-- Labels/indices: W=1 C=2 V=3 D=4 G=5 X=6 Z=7 E=8 T=9 I=10 P=11 Q=12 U=13 Y=14 R=15 A=16
-- Bound apps switch focus to their workspace (no silent), matching yabai follow-on-create.
-- =============================================================================

-- W (1): WebStorm
hl.window_rule({
    name = "webstorm-to-W",
    match = { class = "^jetbrains-webstorm$" },
    workspace = "1",
})

-- C (2): CLion + Cursor (Linux IDE stand-in)
hl.window_rule({
    name = "clion-to-C",
    match = { class = "^jetbrains-clion$" },
    workspace = "2",
})
hl.window_rule({
    name = "cursor-to-C",
    match = { class = "^(cursor|Cursor)$" },
    workspace = "2",
})

-- V (3): Arc/Safari → Firefox / Zen
hl.window_rule({
    name = "firefox-to-V",
    match = { class = "^(firefox|Firefox)$" },
    workspace = "3",
})
hl.window_rule({
    name = "zen-to-V",
    match = { class = "^(zen|zen-browser|Zen|Zen-browser)$" },
    workspace = "3",
})

-- D (4): Yandex Browser (yabai APP_WORKSPACE; aerospace used B — we follow yabai)
hl.window_rule({
    name = "yandex-to-D",
    match = { class = "^[Yy]andex.?[Bb]rowser$" },
    workspace = "4",
})

-- G (5): Google Chrome / Chromium
hl.window_rule({
    name = "chrome-to-G",
    match = { class = "^(google-chrome|Google-chrome|chromium|Chromium|brave-browser|Brave-browser)$" },
    workspace = "5",
})

-- X (6): ChatGPT → Claude (AI chat); ChatGPT desktop is a Zen URL shortcut (no class)
hl.window_rule({
    name = "claude-to-X",
    match = { class = "^com\\.anthropic\\.Claude$" },
    workspace = "6",
})

-- Z (7): WezTerm → kitty
hl.window_rule({
    name = "kitty-to-Z",
    match = { class = "^kitty$" },
    workspace = "7",
})

-- E (8): Finder → Nautilus / Thunar
hl.window_rule({
    name = "nautilus-to-E",
    match = { class = "^(org\\.gnome\\.Nautilus|Nautilus|nautilus)$" },
    workspace = "8",
})
hl.window_rule({
    name = "thunar-to-E",
    match = { class = "^(Thunar|thunar)$" },
    workspace = "8",
})

-- T (9): Telegram
hl.window_rule({
    name = "telegram-to-T",
    match = { class = "^(org\\.telegram\\.desktop|TelegramDesktop)$" },
    workspace = "9",
})

-- Media viewer shares Telegram's class; keep it on the current workspace
hl.window_rule({
    name = "telegram-media-stay",
    match = {
        class = "^(org\\.telegram\\.desktop|TelegramDesktop)$",
        title = "^Media viewer$",
    },
    workspace = "unset",
})

-- I (10): Discord
hl.window_rule({
    name = "discord-to-I",
    match = { class = "^(discord|Discord)$" },
    workspace = "10",
})

-- P (11): Preview → common Linux image/PDF viewers (if installed)
hl.window_rule({
    name = "preview-to-P",
    match = { class = "^(org\\.gnome\\.Evince|evince|org\\.gnome\\.Loupe|loupe|eog|org\\.kde\\.okular|okular|imv)$" },
    workspace = "11",
})

-- Q (12): Wolfram — Mac-only; no Linux rule

-- U (13): Spotify
hl.window_rule({
    name = "spotify-to-U",
    match = { class = "^(spotify|Spotify)$" },
    workspace = "13",
})

-- Y (14): Zoom
hl.window_rule({
    name = "zoom-to-Y",
    match = { class = "^(zoom|Zoom)$" },
    workspace = "14",
})

-- R (15): Notes → Obsidian
hl.window_rule({
    name = "obsidian-to-R",
    match = { class = "^(obsidian|Obsidian)$" },
    workspace = "15",
})

-- A (16): Mail → Thunderbird
hl.window_rule({
    name = "thunderbird-to-A",
    match = { class = "^(thunderbird|Thunderbird|org\\.mozilla\\.Thunderbird)$" },
    workspace = "16",
})

-- =============================================================================
-- Float / unmanaged (yabai manage=off + dialogs + Windscribe from aerospace)
-- =============================================================================

hl.window_rule({
    name = "windscribe-float",
    match = { class = ".*[Ww]indscribe.*" },
    float = true,
})

hl.window_rule({
    name = "jetbrains-toolbox-float",
    match = { class = "^jetbrains-toolbox$" },
    float = true,
})

hl.window_rule({
    name = "dialog-titles-float",
    match = { title = "^(Open|Save|Save As|Export|Import|Preferences|Settings)$" },
    float = true,
})

hl.window_rule({
    name = "settings-inspector-float",
    match = { title = ".*(Preferences|Settings|Inspector).*" },
    float = true,
})

hl.window_rule({
    name = "auth-login-float",
    match = { title = ".*(Authentication|Login|Sign In).*" },
    float = true,
})

-- JetBrains floating dialogs (subset of yabai JETBRAINS_FLOAT_PATTERNS)
hl.window_rule({
    name = "jetbrains-dialogs-float",
    match = {
        class = "^jetbrains-.*$",
        title = "^(Rename|Delete|Move|Copy|Settings|Preferences|Project Structure|Plugins|Keymap|Search Everywhere)$",
    },
    float = true,
})
