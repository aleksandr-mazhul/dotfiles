-- Persist running catalog apps → ~/.local/state/hypr/session-apps
-- Restore is launched by session-autostart.sh; this module freezes saves and
-- exposes last-session workspaces for window placement during that window.

local apps = require("apps")

local M = {}

M._restoring = false
M._shutting_down = false
M._targets = apps.parse_snapshot()
M._rows = apps.parse_snapshot_rows()

local save_timer = nil
local SAVE_DEBOUNCE_MS = 400
local CLOSE_SAVE_DEBOUNCE_MS = 2500
-- Cursor AppImage often maps after 20s; wallpaper theme is async and can
-- outlive autostart. Keep the restoring flag ~90s.
local RESTORE_FREEZE_MS = 90000

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
    return apps.entry_workspace(M._targets[id])
end

function M.restore_side(id)
    return apps.entry_side(M._targets[id])
end

function M.restore_workspaces(id)
    local list = {}
    for _, row in ipairs(M._rows or {}) do
        if row.id == id then
            list[#list + 1] = row.ws
        end
    end
    if #list == 0 then
        local ws = M.restore_workspace(id)
        if ws then
            list[1] = ws
        end
    end
    return list
end

function M.begin_restore()
    M._rows = apps.parse_snapshot_rows()
    M._targets = apps.parse_snapshot()
    M._restoring = true
    M.ensure_restoring_flag()
    hl.timer(function()
        M._restoring = false
        pcall(os.remove, apps.restoring_file)
        -- Do not save here: a wallpaper-killed kitty would wipe it from the snapshot.
    end, { timeout = RESTORE_FREEZE_MS, type = "oneshot" })
end

function M.ensure_restoring_flag()
    apps.ensure_state_dir()
    local file = io.open(apps.restoring_file, "w")
    if file then
        file:write(tostring(os.time() or 0) .. "\n")
        file:close()
    end
end

local function vec_x(v)
    if type(v) == "number" then
        return v
    end
    if type(v) == "table" then
        return v.x or v[1]
    end
    return nil
end

local function collect_running()
    local by_ws = {}
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
                    local x = vec_x(win.at) or 0
                    local list = by_ws[ws.id]
                    if not list then
                        list = {}
                        by_ws[ws.id] = list
                    end
                    list[#list + 1] = { id = app.id, ws = ws.id, x = x }
                end
            end
        end
    end
    local entries = {}
    for _, rows in pairs(by_ws) do
        table.sort(rows, function(a, b)
            if a.x ~= b.x then
                return a.x < b.x
            end
            return a.id < b.id
        end)
        if #rows == 1 then
            entries[#entries + 1] = { id = rows[1].id, ws = rows[1].ws, side = "A" }
        else
            local mid = (rows[1].x + rows[#rows].x) / 2
            for i, row in ipairs(rows) do
                local side
                if i == 1 then
                    side = "L"
                elseif i == #rows then
                    side = "R"
                else
                    side = row.x < mid and "L" or "R"
                end
                entries[#entries + 1] = { id = row.id, ws = row.ws, side = side }
            end
        end
    end
    return entries
end

local function file_row_count()
    return #apps.parse_snapshot_rows()
end

local function snapshot_has_entries(body)
    return body:find("\n[a-z]") ~= nil
end

local function flush_save()
    if M.is_restoring() then
        return
    end
    local entries = collect_running()
    local n = apps.snapshot_row_count(entries)
    -- SIGTERM/poweroff tears windows down before Hyprland exits. Never replace
    -- a good snapshot with empty or a close-storm remnant.
    if n == 0 then
        return
    end
    local prev = file_row_count()
    if M._shutting_down and prev > 0 and n < prev then
        return
    end
    if prev >= 3 and n * 2 < prev then
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
    M._rows = apps.parse_snapshot_rows()
    M._targets = apps.parse_snapshot()
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
    pcall(os.remove, apps.restoring_file)
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
