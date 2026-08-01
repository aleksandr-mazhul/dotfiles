-- GloView — macOS-like Mission Control
-- Plugin loaded from hyprland.lua before this file is required.
-- Plugin options are applied via hyprctl keyword (hl.config plugin block is unsupported in 0.56.1).

local settings = {
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
}

for key, value in pairs(settings) do
    hl.exec_cmd(string.format("hyprctl keyword plugin:gloview:%s %s", key, value))
end

local function gloview(cmd)
    return function()
        hl.exec_cmd("hyprctl -q dispatch gloview:" .. cmd)
    end
end

hl.bind("CTRL + UP", gloview("toggle"))
hl.bind("CTRL + DOWN", gloview("close"))
hl.bind("CTRL + LEFT", gloview("prev"))
hl.bind("CTRL + RIGHT", gloview("next"))
