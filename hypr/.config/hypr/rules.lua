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

-- Bound apps switch focus to their workspace (no silent).
hl.window_rule({
    name = "telegram-to-T",
    match = { class = "org.telegram.desktop" },
    workspace = "3",
})

-- Media viewer shares Telegram's class; keep it on the current workspace
hl.window_rule({
    name = "telegram-media-stay",
    match = {
        class = "org.telegram.desktop",
        title = "^Media viewer$",
    },
    workspace = "unset",
})

hl.window_rule({
    name = "cursor-to-C",
    match = { class = "^(cursor|Cursor)$" },
    workspace = "7",
})
