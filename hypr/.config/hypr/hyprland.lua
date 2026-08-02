-- Hyprland 0.56 Lua config (converted from hyprland.conf)

hl.plugin.load("/home/stranger/.local/lib/hypr/gloview.so")
hl.plugin.load("/home/stranger/.local/lib/hypr/dynamic-cursors.so")

require("monitors")
require("workspaces")

local terminal = "kitty"
local fileManager = "/home/stranger/.local/bin/nautilus-dark --new-window"
local menu = "qs -c rice ipc call launcher toggle"
local browser = "firefox"

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
        blur = {
            enabled = true,
            size = 3,
            passes = 1,
            vibrancy = 0.1696,
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

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
        allow_session_lock_restore = true,
    },

    cursor = {
        no_hardware_cursors = 1,
        enable_hyprcursor = true,
        sync_gsettings_theme = true,
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
        -- Mac-like: slower base speed + adaptive accel (precise slow, faster flicks)
        sensitivity = -0.72,
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll = false,
        },
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

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

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
    hl.exec_cmd("hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    -- OCR models are heavy; script defers ~25s so login stays snappy.
    hl.exec_cmd("~/.config/hypr/scripts/ocr-daemon-start.sh")
    hl.exec_cmd("xrdb -merge ~/.Xresources")
    hl.exec_cmd("~/.config/hypr/scripts/session-autostart.sh")
    hl.exec_cmd("hyprctl dispatch renameworkspace 1 W & hyprctl dispatch renameworkspace 2 E & hyprctl dispatch renameworkspace 3 T & hyprctl dispatch renameworkspace 4 D & hyprctl dispatch renameworkspace 5 Z & hyprctl dispatch renameworkspace 6 X & hyprctl dispatch renameworkspace 7 C & hyprctl dispatch renameworkspace 8 Q & hyprctl dispatch renameworkspace 9 B & hyprctl dispatch renameworkspace 10 U")
    -- Restore last workspace and keep saving focus changes across reboots.
    hl.exec_cmd("~/.config/hypr/scripts/workspace-persist.sh watch")
end)

require("colors-matugen")
require("gloview")
require("dynamic-cursors")
require("binds")
require("rules")
