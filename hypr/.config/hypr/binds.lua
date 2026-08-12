local mainMod = "ALT"
local secondMod = "SUPER"
local p = programs

-- Mac-like app window management (Cmd → Ctrl):
--   Ctrl+W → close tab inside tabbed apps (browser/editor/…); otherwise close window
--   Ctrl+Q → quit the whole app (all windows of the same class)
local function is_tabbed_app(class)
    if not class or class == "" then
        return false
    end
    class = string.lower(class)
    -- Exact / common WM classes
    local exact = {
        zen = true,
        firefox = true,
        librewolf = true,
        waterfox = true,
        chromium = true,
        ["google-chrome"] = true,
        ["brave-browser"] = true,
        brave = true,
        vivaldi = true,
        ["vivaldi-stable"] = true,
        opera = true,
        ["microsoft-edge"] = true,
        ["yandex-browser"] = true,
        thorium = true,
        cursor = true,
        code = true,
        ["code-oss"] = true,
        ["code - oss"] = true,
        ["sublime_text"] = true,
        nautilus = true,
        ["org.gnome.nautilus"] = true,
        dolphin = true,
        thunar = true,
        ["org.kde.dolphin"] = true,
        ["org.gnome.gedit"] = true,
    }
    if exact[class] then
        return true
    end
    -- Fuzzy fallbacks (Flatpak / variant class names)
    return class:find("firefox", 1, true)
        or class:find("chrom", 1, true)
        or class:find("brave", 1, true)
        or class:find("vivaldi", 1, true)
        or class:find("librewolf", 1, true)
        or class:find("zen", 1, true)
        or class:find("yandex", 1, true)
        or class:find("edge", 1, true)
        or class:find("cursor", 1, true)
        or class:find("nautilus", 1, true)
end

hl.bind("CTRL + W", function()
    local focused = hl.get_active_window()
    if not focused then
        return
    end
    -- Like macOS: apps with tabs handle Cmd/Ctrl+W themselves (close tab)
    if is_tabbed_app(focused.class) then
        hl.dispatch(hl.dsp.pass({ window = focused }))
        return
    end
    hl.dispatch(hl.dsp.window.close({ window = focused }))
end)

hl.bind("CTRL + Q", function()
    local focused = hl.get_active_window()
    if not focused then
        return
    end

    local class = focused.class
    if not class or class == "" then
        hl.dispatch(hl.dsp.window.close({ window = focused }))
        return
    end

    local to_close = {}
    for _, win in ipairs(hl.get_windows()) do
        if win.class == class then
            to_close[#to_close + 1] = win
        end
    end
    for _, win in ipairs(to_close) do
        hl.dispatch(hl.dsp.window.close({ window = win }))
    end
end)

-- Telegram Linux has no Mac Cmd+K "Jump to chat" UI. Native `search` = in-chat
-- messages. Esc leaves the current chat and focuses the left chat-list search.
hl.bind("CTRL + K", function()
    local focused = hl.get_active_window()
    if not focused then
        return
    end
    local class = focused.class or ""
    if class == "TelegramDesktop" or class == "org.telegram.desktop" then
        hl.dispatch(hl.dsp.exec_cmd("wtype -k Escape"))
        return
    end
    hl.dispatch(hl.dsp.pass({ window = focused }))
end)

-- Yandex Browser: Ctrl+Shift+C → copy current page URL (elsewhere: pass through).
-- Chromium inhibits compositor shortcuts; dont_inhibit makes the bind win anyway.
hl.bind("CTRL + SHIFT + C", function()
    local focused = hl.get_active_window()
    if not focused then
        return
    end
    local class = string.lower(focused.class or "")
    if class:find("yandex", 1, true) then
        hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/copy-browser-url.sh"))
        return
    end
    hl.dispatch(hl.dsp.pass({ window = focused }))
end, { dont_inhibit = true })

-- Zoom tabs (Meeting / shared screen), same muscle memory as Zen/Arc:
--   Physical: Super+Shift+[ ] (mouse side buttons) → kanata → Ctrl+Page_Up/Down
--   Keyboard: Ctrl+Shift+[ ] also works.
-- IMPORTANT: do NOT also bind Prior/Next — they are aliases of Page_Up/Down and
-- would fire twice (skip every other tab/window).
local function is_zoom(class)
    class = string.lower(class or "")
    return class == "zoom" or class:find("zoom", 1, true) ~= nil
end

local function zoom_tab_or_pass(dir)
    local focused = hl.get_active_window()
    if not focused then
        return
    end
    if is_zoom(focused.class) then
        hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/zoom-tab.sh " .. dir))
        return
    end
    -- One pass only — apps (Zen) / kitty handle Ctrl+PgUp themselves
    hl.dispatch(hl.dsp.pass({ window = focused }))
end

-- After kanata: Super+Shift+[ ] arrives as Ctrl+Page_Up/Down
hl.bind("CTRL + Page_Up", function()
    zoom_tab_or_pass("prev")
end, { dont_inhibit = true })
hl.bind("CTRL + Page_Down", function()
    zoom_tab_or_pass("next")
end, { dont_inhibit = true })

-- Direct Ctrl+Shift+[ ] (keyboard, no kanata)
hl.bind("CTRL + SHIFT + bracketleft", function()
    zoom_tab_or_pass("prev")
end, { dont_inhibit = true })
hl.bind("CTRL + SHIFT + bracketright", function()
    zoom_tab_or_pass("next")
end, { dont_inhibit = true })

-- Do NOT bind SUPER+SHIFT+bracket*: kanata already remaps those to Ctrl+PgUp/Dn.
-- Binding both caused a second pass → skipped tabs in Zen and windows in tmux.
-- Do NOT bind CTRL+TAB here: Firefox/Zen uses MRU order (feels like "skipping").
-- Zoom gets Ctrl+Tab via zoom-tab.sh wtype, not via these binds.

-- Force-kill focused window (escape hatch)
hl.bind(secondMod .. " + SHIFT + Q", hl.dsp.window.kill())
-- Another window of the focused app
hl.bind("CTRL + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/new-window.sh"))

-- =============================================================================
-- Nautilus = Mac Finder shortcuts (Cmd → Ctrl)
--   Ctrl+Backspace / Ctrl+Delete  → Move to Trash
--   Ctrl+Alt+Backspace/Delete     → Delete Immediately
--   Ctrl+D                        → Duplicate (bookmark: Ctrl+Shift+D)
--   Ctrl+↑ / Ctrl+↓               → Enclosing folder / Open
--   Ctrl+[ / Ctrl+]               → Back / Forward
--   Ctrl+Shift+G                  → Go to folder
--   Ctrl+I                        → Get Info
--   Ctrl+= / Ctrl+-               → Zoom icons
--   Ctrl+Shift+.                  → Show hidden
-- =============================================================================
local function is_nautilus(win)
    if not win then
        return false
    end
    local class = string.lower(win.class or "")
    return class:find("nautilus", 1, true) ~= nil
end

local function nautilus_or_pass(action)
    local focused = hl.get_active_window()
    if is_nautilus(focused) then
        hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/nautilus-mac.sh " .. action))
        return
    end
    if focused then
        hl.dispatch(hl.dsp.pass({ window = focused }))
    end
end

hl.bind("CTRL + BACKSPACE", function()
    nautilus_or_pass("trash")
end)

hl.bind("CTRL + DELETE", function()
    nautilus_or_pass("trash")
end)

hl.bind("CTRL + ALT + BACKSPACE", function()
    nautilus_or_pass("purge")
end)

hl.bind("CTRL + ALT + DELETE", function()
    nautilus_or_pass("purge")
end)

hl.bind("CTRL + D", function()
    nautilus_or_pass("duplicate")
end)

hl.bind("CTRL + SHIFT + D", function()
    nautilus_or_pass("bookmark")
end)

hl.bind("CTRL + UP", function()
    nautilus_or_pass("up")
end)

hl.bind("CTRL + DOWN", function()
    nautilus_or_pass("open")
end)

hl.bind("CTRL + bracketleft", function()
    nautilus_or_pass("back")
end)

hl.bind("CTRL + bracketright", function()
    nautilus_or_pass("forward")
end)

hl.bind("CTRL + SHIFT + G", function()
    nautilus_or_pass("goto")
end)

hl.bind("CTRL + I", function()
    nautilus_or_pass("info")
end)

-- Nautilus: Ctrl+Shift+. toggles hidden files (native shortcut is Ctrl+H)
hl.bind("CTRL + SHIFT + PERIOD", function()
    local focused = hl.get_active_window()
    if is_nautilus(focused) then
        hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/nautilus-toggle-hidden.sh"))
        return
    end
    if focused then
        hl.dispatch(hl.dsp.pass({ window = focused }))
    end
end)

-- Nautilus icon zoom: Ctrl+= / Ctrl+-
local function nautilus_zoom(dir)
    local focused = hl.get_active_window()
    if is_nautilus(focused) then
        hl.dispatch(hl.dsp.exec_cmd("~/.config/hypr/scripts/nautilus-zoom.sh " .. dir))
        return true
    end
    return false
end

hl.bind("CTRL + equal", function()
    local focused = hl.get_active_window()
    if nautilus_zoom("in") then
        return
    end
    if focused then
        hl.dispatch(hl.dsp.pass({ window = focused }))
    end
end)

hl.bind("CTRL + minus", function()
    local focused = hl.get_active_window()
    if nautilus_zoom("out") then
        return
    end
    if focused then
        hl.dispatch(hl.dsp.pass({ window = focused }))
    end
end)

-- Float: was Alt+V (taken by skhd workspace V) → Super+Shift+V; also service-mode `f`
hl.bind(secondMod .. " + SHIFT + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
-- Zoom-fullscreen (skhd Alt+Shift+F); bar hide/show → Super+B (Shift+B alias)
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(secondMod .. " + B", hl.dsp.exec_cmd("qs -c rice ipc call bar toggle"))
hl.bind(secondMod .. " + SHIFT + B", hl.dsp.exec_cmd("qs -c rice ipc call bar toggle"))
-- Pin: was Alt+Shift+P (taken by move→P) → Super+Shift+P
hl.bind(secondMod .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }))
-- Pseudo: was Alt+P (taken by workspace P) → Ctrl+Alt+P
hl.bind("CTRL + ALT + P", hl.dsp.window.pseudo())

-- Tabbed stack (mark → join): was Alt+G (taken by workspace G) → Super+G
--   Super+G on window A     → mark (solo group, top line appears)
--   Super+G on window B     → join B into A's stack
--   Super+G again on a stack member → dissolve
--   Super+G on the marked solo again → cancel mark
--   Super+Tab / Super+Shift+Tab → cycle tabs (was Alt+Tab; Alt+Tab = recent workspace)
-- Persists across bind re-runs within a session (cleared on dissolve/cancel)
stack_mark_address = stack_mark_address or nil

hl.bind(secondMod .. " + G", function()
    local win = hl.get_active_window()
    if not win then
        return
    end

    local group = win.group
    local size = group and (group.size or 0) or 0

    -- Already in a real stack → dissolve
    if size >= 2 then
        hl.dispatch(hl.dsp.group.toggle({ window = win }))
        stack_mark_address = nil
        return
    end

    -- Resolve previously marked window (if any)
    local marked = nil
    if stack_mark_address then
        marked = hl.get_window("address:" .. stack_mark_address)
        if not marked then
            stack_mark_address = nil
        end
    end

    -- Super+G on the same marked window again → cancel
    if marked and marked.address == win.address then
        if win.group then
            hl.dispatch(hl.dsp.group.toggle({ window = win }))
        end
        stack_mark_address = nil
        return
    end

    -- Second (or further) window: join into the marked stack
    if marked then
        if not marked.group then
            hl.dispatch(hl.dsp.group.toggle({ window = marked }))
            marked = hl.get_window("address:" .. stack_mark_address) or marked
        end
        if marked.group then
            -- Drop a solo-group on the joiner first, if any
            if win.group and (win.group.size or 0) <= 1 then
                hl.dispatch(hl.dsp.group.toggle({ window = win }))
                win = hl.get_active_window() or win
            end
            marked.group:add(win)
            -- Keep mark so more windows can be added with Super+G
            stack_mark_address = marked.address
            return
        end
        stack_mark_address = nil
    end

    -- First mark: make a solo group so the top line shows
    if not win.group then
        hl.dispatch(hl.dsp.group.toggle({ window = win }))
        win = hl.get_active_window() or win
    end
    stack_mark_address = win.address
end)

hl.bind(secondMod .. " + TAB", hl.dsp.group.next())
hl.bind(secondMod .. " + SHIFT + TAB", hl.dsp.group.prev())
-- Quickshell rice overlays (shared RicePanel design)
hl.bind(secondMod .. " + Q", hl.dsp.exec_cmd("qs -c rice ipc call clipboard toggle"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(p.menu))
-- Alt+J is movefocus down only (legacy togglesplit conflicted with the same key)

hl.bind(secondMod .. " + SHIFT + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind(secondMod .. " + W", hl.dsp.exec_cmd("qs -c rice ipc call wallpaper toggle"))
-- Overlay type filter: was Super+P, now Ctrl+P (shown in panel footers)
hl.bind("CTRL + P", hl.dsp.exec_cmd("qs -c rice ipc call overlay filter"))
hl.bind(secondMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-random"))
hl.bind(secondMod .. " + ALT + W", hl.dsp.exec_cmd("~/.local/bin/waypaper"))
-- Super+V free for apps (nvim visual-block; Mac Ctrl+V → Super). VPN: launcher / QuickSettings.

hl.bind(secondMod .. " + SHIFT + CTRL + 4", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-region.sh"))
hl.bind(secondMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr-region.sh"))

-- Screen record (OBS) + on-screen draw (Gromit-MPX)
hl.bind(secondMod .. " + SHIFT + R", hl.dsp.exec_cmd("~/.local/bin/obs-record-toggle toggle"))
hl.bind(secondMod .. " + ALT + R", hl.dsp.exec_cmd("obs --disable-shutdown-check"))
hl.bind(secondMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/gromit-ctl.sh toggle"))
hl.bind(secondMod .. " + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/gromit-ctl.sh clear"))
hl.bind(secondMod .. " + CTRL + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/gromit-ctl.sh undo"))
hl.bind(secondMod .. " + ALT + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/gromit-ctl.sh visibility"))

-- Focus windows (skhd alt - hjkl)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Warp/move windows (skhd alt + shift - hjkl)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Swap windows (skhd alt + ctrl - hjkl)
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.swap({ direction = "down" }))

-- Resize (skhd alt - / =)
hl.bind(mainMod .. " + MINUS", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + EQUAL", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })

-- Focus / move across monitors (skhd cmd+alt[+shift] - hjkl → Super+Alt[+Shift])
hl.bind(secondMod .. " + ALT + H", hl.dsp.focus({ monitor = "left" }))
hl.bind(secondMod .. " + ALT + L", hl.dsp.focus({ monitor = "right" }))
hl.bind(secondMod .. " + ALT + K", hl.dsp.focus({ monitor = "up" }))
hl.bind(secondMod .. " + ALT + J", hl.dsp.focus({ monitor = "down" }))
hl.bind(secondMod .. " + ALT + SHIFT + H", hl.dsp.window.move({ monitor = "left" }))
hl.bind(secondMod .. " + ALT + SHIFT + L", hl.dsp.window.move({ monitor = "right" }))
hl.bind(secondMod .. " + ALT + SHIFT + K", hl.dsp.window.move({ monitor = "up" }))
hl.bind(secondMod .. " + ALT + SHIFT + J", hl.dsp.window.move({ monitor = "down" }))

-- Workspaces: Mac skhd letter → yabai spaces.sh index (1:1)
-- W=1 C=2 V=3 D=4 G=5 X=6 Z=7 E=8 T=9 I=10 P=11 Q=12 U=13 Y=14 R=15 A=16
local workspaceKeys = {
    W = 1, C = 2, V = 3, D = 4, G = 5, X = 6, Z = 7, E = 8,
    T = 9, I = 10, P = 11, Q = 12, U = 13, Y = 14, R = 15, A = 16,
}

for key, ws in pairs(workspaceKeys) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    -- skhd moves window and follows to that space
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

-- Recent workspace (skhd alt - tab)
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Service mode (skhd alt + shift - semicolon)
hl.bind(mainMod .. " + SHIFT + SEMICOLON", hl.dsp.submap("service"))
hl.define_submap("service", function()
    hl.bind("ESCAPE", hl.dsp.submap("reset"))
    hl.bind("Q", hl.dsp.submap("reset"))
    hl.bind("RETURN", hl.dsp.submap("reset"))
    -- balance-ish: reset split for dwindle
    hl.bind("R", function()
        hl.dispatch(hl.dsp.layout("togglesplit"))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("F", function()
        hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("BACKSPACE", function()
        hl.dispatch(hl.dsp.window.close())
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    -- stack into group toward direction (yabai --stack)
    hl.bind("H", function()
        hl.dispatch(hl.dsp.window.move({ into_group = "l" }))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("J", function()
        hl.dispatch(hl.dsp.window.move({ into_group = "d" }))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("K", function()
        hl.dispatch(hl.dsp.window.move({ into_group = "u" }))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
    hl.bind("L", function()
        hl.dispatch(hl.dsp.window.move({ into_group = "r" }))
        hl.dispatch(hl.dsp.submap("reset"))
    end)
end)

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-volume.sh up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-volume.sh down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-volume.sh mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-brightness.sh down"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
