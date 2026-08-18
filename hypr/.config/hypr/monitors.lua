-- Mirrors monitors.conf (nwg-displays). Explicit outputs only — no empty
-- "preferred" fallback that can force 60 Hz on DP-3.
--
-- DP-3 must sit at 0x0 whenever DP-2 is unplugged. A hardcoded 1080x480 offset
-- leaves a layout hole; Chromium/Yandex xdg_popups (video-translate ⋮ menu)
-- land there and look like they opened on another workspace.

local DP2 = {
    output = "DP-2",
    mode = "1920x1080@165.0",
    scale = 1,
    transform = 1,
}

local DP3 = {
    output = "DP-3",
    mode = "2560x1440@164.8",
    scale = 1.25,
}

local function has_output(name)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == name then
            return true
        end
    end
    return false
end

local applying = false

local function apply_monitor_layout()
    if applying then
        return
    end
    applying = true
    local dual = has_output("DP-2")
    hl.monitor({
        output = DP2.output,
        mode = DP2.mode,
        position = "0x0",
        scale = DP2.scale,
        transform = DP2.transform,
    })
    hl.monitor({
        output = DP3.output,
        mode = DP3.mode,
        position = dual and "1080x480" or "0x0",
        scale = DP3.scale,
    })
    applying = false
end

-- Default for the common case (DP-2 unplugged). Hotplug handler below
-- restores the dual layout when the portrait monitor appears.
hl.monitor({
    output = DP2.output,
    mode = DP2.mode,
    position = "0x0",
    scale = DP2.scale,
    transform = DP2.transform,
})
hl.monitor({
    output = DP3.output,
    mode = DP3.mode,
    position = "0x0",
    scale = DP3.scale,
})

hl.on("hyprland.start", apply_monitor_layout)
hl.on("monitor.added", apply_monitor_layout)
hl.on("monitor.removed", apply_monitor_layout)
