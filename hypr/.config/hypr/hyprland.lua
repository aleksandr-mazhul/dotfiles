-- Hyprland 0.56 Lua config (converted from hyprland.conf)

local home = os.getenv("HOME") or ""

hl.plugin.load(home .. "/.local/lib/hypr/gloview.so")
hl.plugin.load(home .. "/.local/lib/hypr/dynamic-cursors.so")

require("monitors")
require("workspaces")

local terminal = "kitty"
local fileManager = home .. "/.local/bin/nautilus-dark --new-window"
local menu = "qs -c rice ipc call launcher toggle"
local browser = "zen-browser"

-- Expose for binds.lua
programs = {
    terminal = terminal,
    fileManager = fileManager,
    menu = menu,
    browser = browser,
}

hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "macOS-hypr")
hl.env("GTK_ICON_THEME", "Papirus-Dark")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GTK_THEME", "Graphite-Dark")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("HYPRSHOT_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
hl.env("XDG_SCREENSHOTS_DIR", os.getenv("HOME") .. "/Pictures/Screenshots")
hl.env("XDG_PICTURES_DIR", os.getenv("HOME") .. "/Pictures")

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        -- Stronger frost for liquid-glass apps (kitty background_opacity < 1)
        blur = {
            enabled = true,
            size = 8,
            passes = 2,
            vibrancy = 0.1696,
            new_optimizations = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    -- Tabbed groups: native groupbar OFF — rice GroupStackBar draws an inset strip
    group = {
        auto_group = false,
        drag_into_group = 0,
        merge_groups_on_drag = false,
        merge_groups_on_groupbar = false,
        insert_after_current = true,
        col = {
            border_active = { colors = { "rgba(ffb688ee)", "rgba(e5bfa9ee)" }, angle = 45 },
            border_inactive = "rgba(52443caa)",
        },
        groupbar = {
            enabled = false,
        },
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        allow_session_lock_restore = true,
    },

    cursor = {
        no_hardware_cursors = 1,
        enable_hyprcursor = true,
        sync_gsettings_theme = true,
        -- Don't teleport the pointer to the newly focused window on keyboard focus
        no_warps = true,
        warp_on_change_workspace = 0,
    },

    input = {
        kb_layout = "us,ru",
        kb_variant = "",
        kb_model = "",
        -- Win+Space = RuEn default; Ctrl+Space = RuEn when Mac mode is on
        kb_options = "grp:win_space_toggle,grp:ctrl_space_toggle",
        kb_rules = "",
        follow_mouse = 1,
        -- Mac-like key repeat: brightness hold ramps ~16 steps without feeling frantic
        repeat_rate = 25,
        repeat_delay = 250,
        -- Mac-like pointer feel; slower base + adaptive accel
        sensitivity = -0.72,
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll = false,
            -- 1/2/3-finger click → LMB/RMB/MMB (2-finger tap = right click)
            clickfinger_behavior = true,
            tap_to_click = true,
            -- 3-finger drag = hold LMB and move (text selection like macOS)
            drag_3fg = 1,
            tap_and_drag = true,
            disable_while_typing = true,
        },
    },

    gestures = {
        workspace_swipe_distance = 400,
        workspace_swipe_min_speed_to_force = 25,
        workspace_swipe_cancel_ratio = 0.25,
        workspace_swipe_create_new = false,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        -- Fingers left → left workspace, fingers right → right (as requested)
        workspace_swipe_invert = false,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
-- Layer shells (quickshell rice menus/bar): no compositor tween — it stutters on 165Hz.
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "layersIn", enabled = false })
hl.animation({ leaf = "layersOut", enabled = false })
hl.animation({ leaf = "fadeLayersIn", enabled = false })
hl.animation({ leaf = "fadeLayersOut", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 4.2, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 4.2, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 4.2, bezier = "easeOutQuint", style = "slide" })
-- Instant cursor zoom (shake-to-find); animation made grow/shrink feel sluggish
hl.animation({ leaf = "zoomFactor", enabled = false })

-- Mac-like trackpad gestures (3-finger kept free for drag_3fg text select)
-- 4↑ Mission Control · 4↓ close · 4←/→ workspaces
hl.gesture({
    fingers = 4,
    direction = "up",
    action = function()
        hl.plugin.gloview.toggle()
    end,
})
hl.gesture({
    fingers = 4,
    direction = "down",
    action = function()
        hl.plugin.gloview.close()
    end,
})
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- Per-device overrides (names from `hyprctl devices`)
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.72,
    accel_profile = "adaptive",
})
hl.device({
    name = "compx-vgn-dragonfly-4k-receiver-1",
    sensitivity = -0.72,
    accel_profile = "adaptive",
})
hl.device({
    name = "ergohaven-k:03-v3/v4-mouse",
    sensitivity = -0.72,
    accel_profile = "adaptive",
})

hl.on("hyprland.start", function()
    -- VPN first — no delay; script retries until helper is ready.
    hl.exec_cmd("~/.config/hypr/scripts/vpn-autostart.sh")
    -- Rice owns notifications; stop swaync if it grabbed the bus.
    hl.exec_cmd("systemctl --user stop swaync.service")
    -- Wallpaper before UI so the bar never paints over the default logo/flash.
    hl.exec_cmd("swww-daemon")
    hl.exec_cmd("waypaper --restore")
    hl.exec_cmd("qs -c rice -n -d")
    -- Binary lives under /usr/lib; user unit is the reliable start.
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- OCR models are heavy; script defers ~25s so login stays snappy.
    hl.exec_cmd("~/.config/hypr/scripts/ocr-daemon-start.sh")
    hl.exec_cmd("xrdb -merge ~/.Xresources")
    hl.exec_cmd("~/.config/hypr/scripts/session-autostart.sh")
    -- Gromit: do NOT autostart (welcome assistant spam). Starts on first Super+D via gromit-ctl.sh.
    -- Ergohaven: Wayland EN/RU sync (Entropy Live Features hang on Hypr — do not autostart).
    hl.exec_cmd("~/.config/hypr/scripts/eh-layout-sync.sh")
    -- After keyboard appears, restore Vial default layer if configured (see eh-default-layer).
    hl.exec_cmd("~/.config/hypr/scripts/eh-default-layer.sh")
    -- Each window remembers EN/RU; restores on focus (pauses while launcher forces EN).
    hl.exec_cmd("~/.config/hypr/scripts/eh-window-layout.py")
    -- Names match Mac skhd/yabai spaces.sh (W C V D G X Z E T I P Q U Y R A)
    hl.exec_cmd("hyprctl dispatch renameworkspace 1 W & hyprctl dispatch renameworkspace 2 C & hyprctl dispatch renameworkspace 3 V & hyprctl dispatch renameworkspace 4 D & hyprctl dispatch renameworkspace 5 G & hyprctl dispatch renameworkspace 6 X & hyprctl dispatch renameworkspace 7 Z & hyprctl dispatch renameworkspace 8 E & hyprctl dispatch renameworkspace 9 T & hyprctl dispatch renameworkspace 10 I & hyprctl dispatch renameworkspace 11 P & hyprctl dispatch renameworkspace 12 Q & hyprctl dispatch renameworkspace 13 U & hyprctl dispatch renameworkspace 14 Y & hyprctl dispatch renameworkspace 15 R & hyprctl dispatch renameworkspace 16 A")
    -- Restore last workspace and keep saving focus changes across reboots.
    hl.exec_cmd("~/.config/hypr/scripts/workspace-persist.sh watch")
end)

require("colors-matugen")
require("gloview")
require("dynamic-cursors")
require("binds")
require("rules")
