-- Zen/Firefox Picture-in-Picture helpers:
--   • float + pin on all workspaces
--   • remember last position/size across open/close
--   • Ctrl+Super+F: open PiP (passed to Zen), or close and YouTube-fullscreen

local M = {}

local cache_home = os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "") .. "/.cache")
local GEOM_PATH = cache_home .. "/zen-pip-geometry.json"

local PIP_TITLES = {
    ["Picture-in-Picture"] = true,
    ["Картинка в картинке"] = true,
}

local function vec_xy(v)
    if type(v) ~= "table" then
        return nil, nil
    end
    return v.x or v[1], v.y or v[2]
end

local function unwrap_window(win)
    if type(win) == "table" and win.window then
        win = win.window
    end
    if type(win) ~= "userdata" and type(win) ~= "table" then
        return nil
    end
    return win
end

function M.is_pip_window(win)
    win = unwrap_window(win)
    if not win then
        return false
    end
    local title = tostring(win.title or "")
    local initial = tostring(win.initial_title or "")
    return PIP_TITLES[title] == true or PIP_TITLES[initial] == true
end

function M.find_pip()
    for _, win in ipairs(hl.get_windows() or {}) do
        if M.is_pip_window(win) then
            return win
        end
    end
    return nil
end

local function zen_class(class)
    class = string.lower(tostring(class or ""))
    return class == "zen" or class == "zen-browser"
end

function M.find_youtube_zen()
    local fallback = nil
    for _, win in ipairs(hl.get_windows() or {}) do
        if zen_class(win.class) and not M.is_pip_window(win) then
            local title = tostring(win.title or "")
            if title:find("YouTube", 1, true) then
                return win
            end
            fallback = fallback or win
        end
    end
    return fallback
end

local function write_geom(x, y, w, h)
    if not x or not y or not w or not h then
        return
    end
    if w < 160 or h < 90 then
        return
    end
    local f = io.open(GEOM_PATH, "w")
    if not f then
        return
    end
    f:write(string.format('{"x":%d,"y":%d,"w":%d,"h":%d}\n', math.floor(x), math.floor(y), math.floor(w), math.floor(h)))
    f:close()
end

function M.save_geometry(win)
    win = unwrap_window(win) or M.find_pip()
    if not win or not M.is_pip_window(win) then
        return
    end
    local x, y = vec_xy(win.at)
    local w, h = vec_xy(win.size)
    write_geom(x, y, w, h)
end

local function load_geometry()
    local f = io.open(GEOM_PATH, "r")
    if not f then
        return nil
    end
    local raw = f:read("*a")
    f:close()
    if not raw or raw == "" then
        return nil
    end
    local x = tonumber(raw:match('"x"%s*:%s*([%-]?%d+)'))
    local y = tonumber(raw:match('"y"%s*:%s*([%-]?%d+)'))
    local w = tonumber(raw:match('"w"%s*:%s*(%d+)'))
    local h = tonumber(raw:match('"h"%s*:%s*(%d+)'))
    if not x or not y or not w or not h then
        return nil
    end
    return { x = x, y = y, w = w, h = h }
end

local function apply_geometry(win, geom)
    win = unwrap_window(win)
    if not win or not geom then
        return
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.resize({
            x = geom.w,
            y = geom.h,
            window = win,
        }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.focus({ window = win }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.window.move({
            x = geom.x,
            y = geom.y,
            relative = false,
        }))
    end)
end

function M.restore_geometry(win)
    win = unwrap_window(win)
    if not win or not M.is_pip_window(win) then
        return
    end
    local geom = load_geometry()
    if not geom then
        return
    end
    apply_geometry(win, geom)
end

local function focus_zen(zen)
    if not zen then
        return
    end
    if zen.workspace and zen.workspace.id then
        pcall(function()
            hl.dispatch(hl.dsp.focus({ workspace = zen.workspace.id }))
        end)
    end
    pcall(function()
        hl.dispatch(hl.dsp.focus({ window = zen }))
    end)
end

local function youtube_player_fullscreen(zen)
    if not zen then
        return
    end
    focus_zen(zen)
    -- Click roughly on the player so YouTube keybinds apply, then `f`.
    local x, y = vec_xy(zen.at)
    local w, h = vec_xy(zen.size)
    if x and y and w and h then
        local cx = math.floor(x + w / 2)
        local cy = math.floor(y + h * 0.42)
        pcall(function()
            hl.dispatch(hl.dsp.cursor.move({ x = cx, y = cy }))
        end)
        pcall(function()
            hl.dispatch(hl.dsp.send_key_state({
                mods = "",
                key = "BTN_LEFT",
                state = "down",
                window = zen,
            }))
        end)
        pcall(function()
            hl.dispatch(hl.dsp.send_key_state({
                mods = "",
                key = "BTN_LEFT",
                state = "up",
                window = zen,
            }))
        end)
    end
    pcall(function()
        hl.dispatch(hl.dsp.send_shortcut({
            mods = "",
            key = "f",
            window = zen,
        }))
    end)
end

--- Close PiP (if any) and return the video to YouTube player fullscreen.
function M.close_to_youtube()
    local pip = M.find_pip()
    if not pip then
        return false
    end
    M.save_geometry(pip)
    local zen = M.find_youtube_zen()
    -- Close via WM so we don't re-fire the Ctrl+Super+F Hyprland bind.
    pcall(function()
        hl.dispatch(hl.dsp.window.close({ window = pip }))
    end)
    hl.timer(function()
        local z = M.find_youtube_zen() or zen
        youtube_player_fullscreen(z)
    end, { timeout = 280, type = "oneshot" })
    return true
end

--- Open PiP by passing the current keybind through to Zen (Zen owns the shortcut).
function M.open_via_pass()
    local zen = M.find_youtube_zen()
    if not zen then
        return
    end
    focus_zen(zen)
    pcall(function()
        hl.dispatch(hl.dsp.pass({ window = zen }))
    end)
end

--- Programmatic toggle (tests / scripts). Avoids bind re-entry by using window.close.
function M.toggle()
    if M.find_pip() then
        M.close_to_youtube()
        return
    end
    local zen = M.find_youtube_zen()
    if not zen then
        return
    end
    focus_zen(zen)
    pcall(function()
        hl.dispatch(hl.dsp.send_shortcut({
            mods = "CTRL SUPER",
            key = "f",
            window = zen,
        }))
    end)
end

hl.window_rule({
    name = "zen-picture-in-picture",
    match = { title = "^(Picture-in-Picture|Картинка в картинке)$" },
    float = true,
    pin = true,
    no_anim = true,
    border_size = 0,
    rounding = 12,
})

local function on_pip_open(win)
    win = unwrap_window(win)
    if not win or not M.is_pip_window(win) then
        return
    end
    hl.timer(function()
        M.restore_geometry(win)
    end, { timeout = 40, type = "oneshot" })
    hl.timer(function()
        M.restore_geometry(win)
    end, { timeout = 180, type = "oneshot" })
end

local function on_pip_close(win)
    win = unwrap_window(win)
    if not win or not M.is_pip_window(win) then
        return
    end
    M.save_geometry(win)
end

hl.on("window.open_early", on_pip_open)
hl.on("window.open", on_pip_open)
hl.on("window.close", on_pip_close)
hl.on("window.destroy", on_pip_close)

return M
