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

-- Rice liquid glass: frost wallpaper through translucent panels (alpha ~0.80).
-- ignore_alpha skips fully/near-transparent pixels so blur hugs the rounded rect.
-- NOT on rice-panel: that layer is fullscreen + dim scrim; blur on it paints a gray
-- fog/band under the bar. Anchored hubs (QS/calendar/notifs) stay frosted.
hl.layer_rule({
    name = "rice-glass-blur",
    match = { namespace = "^rice-(quicksettings|calendar|notifications)$" },
    blur = true,
    ignore_alpha = 0.2,
})

-- DS popup surfaces (launcher & future popups): one glass pane, NO fullscreen
-- dim (design-system anti-pattern #6 — dim kills the material). The layer is
-- fully transparent outside the pane, so ignore_alpha frosts only the glass.
hl.layer_rule({
    name = "rice-popup-glass",
    match = { namespace = "^rice-popup$" },
    blur = true,
    ignore_alpha = 0.2,
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
--
-- Only TILE the first/main window to the home workspace. Floating children
-- (Telegram RMB menus, media viewer, dialogs) stay on the current workspace.
-- If the app was moved off its home, new windows follow the existing instance
-- (see window.open handler below) — so popups never "fly" to the home letter.
-- =============================================================================

local APP_HOME = {
    -- name, class regex (Hyprland PCRE), workspace id, exact classes for Lua follow-handler
    { "webstorm", "^jetbrains-webstorm$", "1", { "jetbrains-webstorm" } },
    { "clion", "^jetbrains-clion$", "2", { "jetbrains-clion" } },
    { "cursor", "^(cursor|Cursor)$", "2", { "cursor", "Cursor" } },
    { "firefox", "^(firefox|Firefox)$", "3", { "firefox", "Firefox" } },
    { "zen", "^(zen|zen-browser|Zen|Zen-browser)$", "3", { "zen", "zen-browser", "Zen", "Zen-browser" } },
    { "yandex", "^[Yy]andex.?[Bb]rowser$", "4", { "yandex-browser", "Yandex-browser" } },
    {
        "chrome",
        "^(google-chrome|Google-chrome|chromium|Chromium|brave-browser|Brave-browser)$",
        "5",
        { "google-chrome", "Google-chrome", "chromium", "Chromium", "brave-browser", "Brave-browser" },
    },
    { "claude", "^com\\.anthropic\\.Claude$", "6", { "com.anthropic.Claude" } },
    { "kitty", "^kitty$", "7", { "kitty" } },
    {
        "nautilus",
        "^(org\\.gnome\\.Nautilus|Nautilus|nautilus)$",
        "8",
        { "org.gnome.Nautilus", "Nautilus", "nautilus" },
    },
    { "thunar", "^(Thunar|thunar)$", "8", { "Thunar", "thunar" } },
    {
        "telegram",
        "^(org\\.telegram\\.desktop|TelegramDesktop)$",
        "9",
        { "org.telegram.desktop", "TelegramDesktop" },
    },
    { "discord", "^(discord|Discord)$", "10", { "discord", "Discord" } },
    {
        "preview",
        "^(org\\.gnome\\.Evince|evince|org\\.gnome\\.Loupe|loupe|eog|org\\.kde\\.okular|okular|imv)$",
        "11",
        { "org.gnome.Evince", "evince", "org.gnome.Loupe", "loupe", "eog", "org.kde.okular", "okular", "imv" },
    },
    { "spotify", "^(spotify|Spotify)$", "13", { "spotify", "Spotify" } },
    { "zoom", "^(zoom|Zoom)$", "14", { "zoom", "Zoom" } },
    { "obs", "^(com\\.obsproject\\.Studio|obs)$", "14", { "com.obsproject.Studio", "obs" } },
    { "obsidian", "^(obsidian|Obsidian)$", "15", { "obsidian", "Obsidian" } },
    {
        "thunderbird",
        "^(thunderbird|Thunderbird|org\\.mozilla\\.Thunderbird)$",
        "16",
        { "thunderbird", "Thunderbird", "org.mozilla.Thunderbird" },
    },
}

local BOUND_CLASS = {}
for _, app in ipairs(APP_HOME) do
    local name, class_re, ws, classes = app[1], app[2], app[3], app[4]
    hl.window_rule({
        name = name .. "-to-" .. ws,
        match = { class = class_re, float = false },
        workspace = ws,
    })
    hl.window_rule({
        name = name .. "-float-stay",
        match = { class = class_re, float = true },
        workspace = "unset",
    })
    for _, c in ipairs(classes) do
        BOUND_CLASS[c] = true
    end
end

-- Nautilus draws its own CSD chrome; Hypr's border reads as a thick orange/black
-- frame (worse with fractional scale). Same for float menus/popovers.
hl.window_rule({
    name = "nautilus-no-border",
    match = {
        class = "^(org\\.gnome\\.Nautilus|Nautilus|nautilus)$",
    },
    border_size = 0,
})

-- Telegram RMB menus / media viewer already have their own chrome — Hypr's
-- active border shows up as a weird thick outline on fractional scale.
hl.window_rule({
    name = "telegram-float-no-border",
    match = {
        class = "^(org\\.telegram\\.desktop|TelegramDesktop)$",
        float = true,
    },
    border_size = 0,
})

-- Kitty glass: leave Hyprland window opacity at 1 — kitty owns alpha via
-- background_opacity; decoration.blur (hyprland.lua) frosts the wallpaper behind it.

-- Q (12): Wolfram — Mac-only; no Linux rule

-- If an app instance already exists (possibly moved off its home), keep new
-- windows of that class on the same workspace as the existing one.
hl.on("window.open", function(win)
    -- Event may pass the window directly or a table with .window
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return
    end
    local class = win.class
    if not class or not BOUND_CLASS[class] then
        return
    end

    local best = nil
    local best_hist = nil
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= win.address and other.class == class and other.workspace then
            local hist = other.focus_history_id or 999999
            if best == nil or hist < best_hist then
                best = other
                best_hist = hist
            end
        end
    end
    if not best or not best.workspace then
        return
    end

    local target = best.workspace
    local cur = win.workspace
    if cur and target and cur.id == target.id then
        return
    end

    -- Silent: don't yank the view when a popup/dialog follows the parent app.
    local ok = pcall(function()
        hl.dispatch(hl.dsp.window.move({
            window = win,
            workspace = target.id,
            silent = true,
        }))
    end)
    if not ok then
        pcall(function()
            hl.dispatch(hl.dsp.window.move({
                window = win,
                workspace = target.id,
            }))
        end)
    end
end)

-- =============================================================================
-- Float / unmanaged (yabai manage=off + dialogs + Windscribe from aerospace)
-- =============================================================================

-- Let Hyprland binds (e.g. Ctrl+Shift+C → copy URL) override Chromium shortcut inhibit
hl.window_rule({
    name = "yandex-no-shortcuts-inhibit",
    match = { class = "^[Yy]andex.?[Bb]rowser$" },
    no_shortcuts_inhibit = true,
})

-- Zoom: don't block Ctrl+Tab tab switching
hl.window_rule({
    name = "zoom-no-shortcuts-inhibit",
    match = { class = "^(zoom|Zoom)$" },
    no_shortcuts_inhibit = true,
})

-- Gromit-MPX overlay: stay above everything, never steal focus permanently
hl.window_rule({
    name = "gromit-overlay",
    match = { class = "^(Gromit-mpx|gromit-mpx|net\\.christianbeier\\.Gromit-MPX)$" },
    float = true,
    pin = true,
    no_anim = true,
    opacity = "1.0 override",
})

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
