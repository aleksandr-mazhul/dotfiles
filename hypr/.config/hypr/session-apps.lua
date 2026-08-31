-- Persist running catalog apps → ~/.local/state/hypr/session-apps
-- Restore is launched by session-autostart.sh; this module freezes saves and
-- exposes last-session workspaces for window placement during that window.

local apps = require("apps")

local M = {}

M._restoring = false
M._shutting_down = false
M._targets = apps.parse_snapshot()

local save_timer = nil
local SAVE_DEBOUNCE_MS = 400
local CLOSE_SAVE_DEBOUNCE_MS = 2500
-- Cursor AppImage often maps after 20s; keep placement/save freeze until then.
local RESTORE_FREEZE_MS = 60000

local function valid_workspace(ws)
    if not ws or ws.special then
        return false
    end
    local id = ws.id
    return type(id) == "number" and id >= 1 and id <= 16
end

function M.is_restoring()
    return M._restoring or apps.restoring_flag_present()
end

function M.restore_workspace(id)
    return M._targets[id]
end

function M.begin_restore()
    M._targets = apps.parse_snapshot()
    M._restoring = true
    hl.timer(function()
        M._restoring = false
        pcall(os.remove, apps.restoring_file)
        M.schedule_save()
    end, { timeout = RESTORE_FREEZE_MS, type = "oneshot" })
end

local function collect_running()
    local best = {}
    local windows = hl.get_windows()
    if not windows then
        return {}
    end
    for _, win in ipairs(windows) do
        if win.mapped ~= false and not win.hidden and not win.floating then
            local ws = win.workspace
            if valid_workspace(ws) then
                local app = apps.app_for_class(win.class)
                if app and app.cmd then
                    local hist = win.focus_history_id or 999999
                    local prev = best[app.id]
                    if not prev or hist < prev.hist then
                        best[app.id] = { ws = ws.id, hist = hist }
                    end
                end
            end
        end
    end
    local entries = {}
    for id, row in pairs(best) do
        entries[id] = row.ws
    end
    return entries
end

local function snapshot_has_entries(body)
    return body:find("\n[a-z]") ~= nil
end

local function flush_save()
    if M.is_restoring() then
        return
    end
    local entries = collect_running()
    -- SIGTERM/poweroff tears windows down before Hyprland exits. Never replace
    -- a good snapshot with empty; mid-session closes still persist via debounce
    -- once at least one catalog app remains.
    if not next(entries) then
        return
    end
    apps.ensure_state_dir()
    local body = apps.format_snapshot(entries)
    if not snapshot_has_entries(body) then
        return
    end
    local tmp = apps.state_file .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then
        return
    end
    file:write(body)
    file:close()
    os.rename(tmp, apps.state_file)
end

-- Hyprland oneshot timers do not re-fire after set_enabled(true). Always
-- allocate a fresh timer; disable any previous debounce first.
function M.schedule_save(delay_ms)
    if M.is_restoring() or M._shutting_down then
        return
    end
    delay_ms = delay_ms or SAVE_DEBOUNCE_MS
    if type(delay_ms) ~= "number" then
        delay_ms = SAVE_DEBOUNCE_MS
    end
    if save_timer then
        pcall(function()
            save_timer:set_enabled(false)
        end)
        save_timer = nil
    end
    save_timer = hl.timer(function()
        save_timer = nil
        flush_save()
    end, { timeout = delay_ms, type = "oneshot" })
end

hl.on("window.open", function()
    M.schedule_save()
end)

hl.on("window.close", function()
    -- Longer debounce so a poweroff close-storm dies with the compositor
    -- before it can shrink the snapshot.
    M.schedule_save(CLOSE_SAVE_DEBOUNCE_MS)
end)

hl.on("window.move_to_workspace", function()
    M.schedule_save()
end)

hl.on("hyprland.shutdown", function()
    M._shutting_down = true
    M._restoring = false
    if save_timer then
        pcall(function()
            save_timer:set_enabled(false)
        end)
        save_timer = nil
    end
    flush_save()
end)

session_apps = M

return M
