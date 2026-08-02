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
-- Force-kill focused window (escape hatch)
hl.bind(secondMod .. " + SHIFT + Q", hl.dsp.window.kill())
-- Another window of the focused app
hl.bind("CTRL + N", hl.dsp.exec_cmd("~/.config/hypr/scripts/new-window.sh"))

hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("qs -c rice ipc call bar toggle"))
-- Pin stays on all workspaces (best with float: Alt+V then Alt+Shift+P)
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }))

-- Tabbed stack (mark → join), does NOT touch Alt+Shift+HJKL swaps:
--   Alt+G on window A     → mark (solo group, top line appears)
--   Alt+G on window B     → join B into A's stack
--   Alt+G again on a stack member → dissolve
--   Alt+G on the marked solo again → cancel mark
--   Alt+Tab / Alt+Shift+Tab → cycle tabs
-- Persists across bind re-runs within a session (cleared on dissolve/cancel)
stack_mark_address = stack_mark_address or nil

hl.bind(mainMod .. " + G", function()
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

    -- Alt+G on the same marked window again → cancel
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
            -- Keep mark so more windows can be added with Alt+G
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

hl.bind(mainMod .. " + TAB", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.group.prev())
-- Quickshell rice overlays (shared RicePanel design)
hl.bind(secondMod .. " + Q", hl.dsp.exec_cmd("qs -c rice ipc call clipboard toggle"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(p.menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- Alt+J is movefocus down only (legacy togglesplit conflicted with the same key)

hl.bind(secondMod .. " + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind(secondMod .. " + W", hl.dsp.exec_cmd("qs -c rice ipc call wallpaper toggle"))
hl.bind(secondMod .. " + P", hl.dsp.exec_cmd("qs -c rice ipc call overlay filter"))
hl.bind(secondMod .. " + SHIFT + W", hl.dsp.exec_cmd("~/.local/bin/wallpaper-random"))
hl.bind(secondMod .. " + ALT + W", hl.dsp.exec_cmd("~/.local/bin/waypaper"))
hl.bind(secondMod .. " + V", hl.dsp.exec_cmd("qs -c rice ipc call vpn toggle"))

hl.bind(secondMod .. " + SHIFT + CTRL + 4", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenshot-region.sh"))
hl.bind(secondMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/ocr-region.sh"))

hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Move/swap windows (plain — does NOT enter groups)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

local workspaceKeys = {
    W = 1, E = 2, T = 3, D = 4, Z = 5,
    X = 6, C = 7, Q = 8, B = 9, U = 10,
}

for key, ws in pairs(workspaceKeys) do
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = ws }))
end

hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-brightness.sh up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("~/.config/hypr/scripts/qs-brightness.sh down"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
