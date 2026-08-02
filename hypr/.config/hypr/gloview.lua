-- GloView — macOS-like Mission Control
-- Plugin loaded from hyprland.lua before this file is required.
-- On Lua backend, use hl.plugin.gloview.* — hyprctl dispatch gloview:… is broken
-- (hyprctl wraps plugin names as Lua syntax).

hl.config({
    plugin = {
        gloview = {
            layout = "rows",
            gap = 34,
            padding = 80,
            padding_top = 40,
            padding_bottom = 70,
            duration = 360,
            preview_round = 12,
            blur = 1,
            switch_animation = 1,
            move_animation = 1,
            anchor = "top",
            strip_height = 150,
            strip_margin = 22,
            strip_gap = 18,
            focus_follows_mouse = 1,
            scroll_switches_workspace = 1,
            exit_on_click = 1,
            key_close = "escape",
            key_activate = "enter",
            key_all_workspaces = "a",
            dynamic_workspaces = 0,
            show_empty = 1,
            autodelete_empty = 0,
            show_workspace_labels = 1,
            show_window_labels = 1,
            strip_all_card = 1,
        },
    },
})

-- Mission Control: Super+↑ (Super+arrows free — text nav is Alt/Ctrl via kanata)
hl.bind("SUPER + UP", hl.plugin.gloview.toggle)
hl.bind("SUPER + DOWN", hl.plugin.gloview.close)
hl.bind("SUPER + LEFT", hl.plugin.gloview.prev)
hl.bind("SUPER + RIGHT", hl.plugin.gloview.next)
