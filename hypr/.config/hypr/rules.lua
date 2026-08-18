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
    ignore_alpha = 0.03,
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

-- Yandex Browser weather / promo toasts are normal top-level windows on Wayland.
-- Without float they tile into giant empty panes (orange Hypr border, almost blank).
-- Kill them; keep real browser tabs (titles end with "Yandex Browser").
local function yandex_weather_spam(win)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return false
    end
    local class = tostring(win.class or ""):lower()
    if not class:find("yandex", 1, true) then
        return false
    end
    local title = tostring(win.title or "")
    local initial = tostring(win.initial_title or "")
    -- Real browser chrome always includes the product name.
    if title:find("Browser", 1, true) or initial:find("Browser", 1, true) then
        return false
    end
    local hay = title .. "\n" .. initial
    return hay:find("Погода", 1, true)
        or hay:find("Прогноз", 1, true)
        or hay:find("Yandex Weather", 1, true)
        or hay:find("Weather forecast", 1, true)
end

local function close_yandex_weather_spam(win)
    if not yandex_weather_spam(win) then
        return
    end
    if type(win) == "table" and win.window then
        win = win.window
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.close({ window = win }))
    end)
end

hl.on("window.open_early", close_yandex_weather_spam)
hl.on("window.open", close_yandex_weather_spam)
hl.on("window.title", close_yandex_weather_spam)

-- If close races the map, at least don't tile a fullscreen empty toast.
hl.window_rule({
    name = "yandex-weather-toast-float",
    match = {
        class = "^[Yy]andex.?[Bb]rowser$",
        title = ".*(Погода|Прогноз|Yandex Weather|Weather forecast).*",
    },
    float = true,
    no_focus = true,
    no_anim = true,
    border_size = 0,
})

-- Video-translate ⋮ menu, language picker, extension bubbles, etc. are extra
-- xdg_toplevels on Wayland (same class as the browser). If they map tiled they
-- get sent to workspace D; if they map floating at 0x0 they land in the dead
-- layout hole left of DP-3 (DP-2 is configured at 0x0 but often unplugged).
-- Either way the menu looks like it "opened on another workspace".
local YANDEX_POPUP_LOG = (os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "") .. "/.cache"))
    .. "/yandex-windows.log"

local function yandex_log(msg)
    local f = io.open(YANDEX_POPUP_LOG, "a")
    if not f then
        return
    end
    f:write(string.format("%s\t%s\n", os.date("!%Y-%m-%dT%H:%M:%SZ"), msg))
    f:close()
end

local function vec_xy(v)
    if type(v) ~= "table" then
        return nil, nil
    end
    return v.x or v[1], v.y or v[2]
end

local function yandex_class_of(win)
    local class = tostring(win.class or ""):lower()
    return class:find("yandex", 1, true) ~= nil
end

local function yandex_is_browser_chrome(win)
    local title = tostring(win.title or "")
    local initial = tostring(win.initial_title or "")
    return title:find("Browser", 1, true)
        or initial:find("Browser", 1, true)
        or title:find("Браузер", 1, true)
        or initial:find("Браузер", 1, true)
end

local function yandex_main_window(except)
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= except.address and yandex_class_of(other) and yandex_is_browser_chrome(other) then
            return other
        end
    end
    return nil
end

local function popup_off_monitors(win)
    local x, y = vec_xy(win.at)
    local w, h = vec_xy(win.size)
    if not x or not y then
        return true
    end
    w, h = w or 1, h or 1
    return hl.get_monitor_at(x + 8, y + 8) == nil
        and hl.get_monitor_at(x + w / 2, y + h / 2) == nil
end

local function rescue_yandex_popup(win, why)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return
    end
    if not yandex_class_of(win) then
        return
    end
    if yandex_weather_spam(win) then
        return
    end
    -- First/main window, or a real second browser window: leave tiled.
    if yandex_is_browser_chrome(win) or not yandex_main_window(win) then
        return
    end

    local ax, ay = vec_xy(win.at)
    local sx, sy = vec_xy(win.size)
    yandex_log(string.format(
        "popup why=%s title=%q initial=%q float=%s at=%s,%s size=%s,%s ws=%s",
        why,
        tostring(win.title or ""),
        tostring(win.initial_title or ""),
        tostring(win.floating),
        tostring(ax),
        tostring(ay),
        tostring(sx),
        tostring(sy),
        win.workspace and tostring(win.workspace.name or win.workspace.id) or "?"
    ))

    if not win.floating then
        pcall(function()
            hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
        end)
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.set_prop({ prop = "border_size", value = "0", window = win }))
    end)

    local parent = yandex_main_window(win)
    if parent and parent.workspace and (not win.workspace or win.workspace.id ~= parent.workspace.id) then
        pcall(function()
            hl.dispatch(hl.dsp.window.move({
                window = win,
                workspace = parent.workspace.id,
                follow = false,
            }))
        end)
    end

    if popup_off_monitors(win) then
        local cursor = hl.get_cursor_pos()
        local mon = hl.get_monitor_at_cursor() or (parent and parent.monitor) or hl.get_active_monitor()
        local tx, ty
        if cursor then
            tx, ty = cursor.x, cursor.y
        elseif mon then
            tx, ty = (mon.x or 0) + 80, (mon.y or 0) + 80
        end
        if tx and ty then
            -- Keep the menu on the visible output; ⋮ is usually under the cursor.
            local mw, mh = vec_xy(win.size)
            mw, mh = mw or 280, mh or 360
            if mon then
                local mx, my = mon.x or 0, mon.y or 0
                local mon_w = (type(mon.size) == "table" and (mon.size.x or mon.size[1])) or mon.width or 1920
                local mon_h = (type(mon.size) == "table" and (mon.size.y or mon.size[2])) or mon.height or 1080
                if mon.scale and mon.scale > 1.01 and mon_w >= 2200 then
                    mon_w = mon_w / mon.scale
                    mon_h = mon_h / mon.scale
                end
                if tx + mw > mx + mon_w - 8 then
                    tx = mx + mon_w - mw - 8
                end
                if ty + mh > my + mon_h - 8 then
                    ty = my + mon_h - mh - 8
                end
                if tx < mx + 8 then
                    tx = mx + 8
                end
                if ty < my + 8 then
                    ty = my + 8
                end
            end
            pcall(function()
                hl.dispatch(hl.dsp.window.move({
                    x = math.floor(tx),
                    y = math.floor(ty),
                    relative = false,
                    window = win,
                }))
            end)
            yandex_log(string.format("popup rescued → %s,%s", tostring(tx), tostring(ty)))
        else
            pcall(function()
                hl.dispatch(hl.dsp.window.center({ window = win }))
            end)
            yandex_log("popup rescued → center")
        end
    end
end

hl.on("window.open_early", function(win)
    rescue_yandex_popup(win, "open_early")
end)
hl.on("window.open", function(win)
    rescue_yandex_popup(win, "open")
end)
hl.on("window.title", function(win)
    rescue_yandex_popup(win, "title")
end)
hl.on("window.open", function(win)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return
    end
    if not yandex_class_of(win) then
        return
    end
    hl.timer(function()
        rescue_yandex_popup(win, "deferred")
    end, { timeout = 80, type = "oneshot" })
end)

-- Zoom: don't block Ctrl+Tab tab switching
hl.window_rule({
    name = "zoom-no-shortcuts-inhibit",
    match = { class = "^(zoom|Zoom)$" },
    no_shortcuts_inhibit = true,
})

-- Zoom annotate / classic whiteboard on XWayland often renders a mostly-transparent
-- surface. With decoration.blur that becomes a frosted pane + pen cursor — looks like
-- a random "draw mode" overlay. Force opaque / no blur; keep Meeting usable.
hl.window_rule({
    name = "zoom-no-frost-overlay",
    match = { class = "^(zoom|Zoom)$" },
    no_blur = true,
    opaque = true,
})

-- During a call Zoom often opens Workplace/Home next to Meeting. Closing it
-- makes Zoom recreate it; park Home on special:zoom instead (Ctrl+W toggles).
local function zoom_has_meeting()
    for _, w in ipairs(hl.get_windows()) do
        local class = string.lower(w.class or "")
        if (class == "zoom" or class:find("zoom", 1, true)) and (w.title == "Meeting" or (w.title or ""):find("^Meeting ")) then
            return true
        end
    end
    return false
end

local function maybe_stash_zoom_home(win)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return
    end
    local class = string.lower(win.class or "")
    if class ~= "zoom" and not class:find("zoom", 1, true) then
        return
    end
    local title = win.title or ""
    if title ~= "Meeting" and not title:find("^Meeting ") then
        -- Home / Workplace shell
        if title:find("Zoom Workplace", 1, true) or title == "Zoom" then
            if zoom_has_meeting() then
                pcall(function()
                    hl.dispatch(hl.dsp.window.move({
                        window = win,
                        workspace = "special:zoom",
                        silent = true,
                    }))
                end)
            end
        end
        return
    end
    -- Meeting just appeared: stash any existing Home windows.
    for _, other in ipairs(hl.get_windows()) do
        if other.address ~= win.address then
            local oc = string.lower(other.class or "")
            local ot = other.title or ""
            if (oc == "zoom" or oc:find("zoom", 1, true))
                and (ot:find("Zoom Workplace", 1, true) or ot == "Zoom")
            then
                pcall(function()
                    hl.dispatch(hl.dsp.window.move({
                        window = other,
                        workspace = "special:zoom",
                        silent = true,
                    }))
                end)
            end
        end
    end
end

hl.on("window.open", maybe_stash_zoom_home)

-- Log every Zoom window (title/class) so we can identify annotate/whiteboard popups.
-- Also auto-close known draw/whiteboard shells that aren't the real Meeting.
local function zoom_draw_spam(win)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return
    end
    local class = string.lower(win.class or "")
    if class ~= "zoom" and not class:find("zoom", 1, true) then
        return
    end
    local title = tostring(win.title or "")
    local initial = tostring(win.initial_title or "")
    local log = io.open((os.getenv("XDG_CACHE_HOME") or (os.getenv("HOME") .. "/.cache")) .. "/zoom-windows.log", "a")
    if log then
        log:write(string.format("%s\t%s\t%s\tfloat=%s\n", os.date("!%Y-%m-%dT%H:%M:%SZ"), title, initial, tostring(win.floating)))
        log:close()
    end
    local hay = title .. "\n" .. initial
    -- Keep Meeting + Workplace + security; kill annotate/whiteboard ghosts.
    if title == "Meeting" or title:find("^Meeting ") or title:find("Zoom Workplace", 1, true) or title:find("security", 1, true) then
        return
    end
    if hay:find("[Ww]hiteboard")
        or hay:find("[Aa]nnotat")
        or hay:find("[Cc]anvas")
        or hay:find("[Dd]rawing")
        or (win.floating and title == "")
    then
        pcall(function()
            hl.dispatch(hl.dsp.window.close({ window = win }))
        end)
    end
end

hl.on("window.open", zoom_draw_spam)
hl.on("window.title", zoom_draw_spam)

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
