-- Shared app catalog: class matching, default workspaces, restore launch cmds.
-- Labels: W=1 C=2 V=3 D=4 G=5 X=6 Z=7 E=8 T=9 I=10 P=11 Q=12 U=13 Y=14 R=15 A=16

local home = os.getenv("HOME") or ""

local M = {}

-- cmd = shell command to restore this app, or nil if we only place (never relaunch).
M.catalog = {
    {
        id = "webstorm",
        class_re = "^jetbrains-webstorm$",
        workspace = 1,
        classes = { "jetbrains-webstorm" },
        cmd = "$HOME/.local/bin/webstorm",
    },
    {
        id = "clion",
        class_re = "^jetbrains-clion$",
        workspace = 2,
        classes = { "jetbrains-clion" },
        cmd = "clion",
    },
    {
        id = "cursor",
        class_re = "^(cursor|Cursor)$",
        workspace = 2,
        classes = { "cursor", "Cursor" },
        cmd = home .. "/.local/bin/cursor", -- wrapper → ~/applications/Cursor.AppImage
    },
    {
        id = "code",
        class_re = "^(code|Code)$",
        workspace = 16,
        classes = { "code", "Code" },
        cmd = "code",
    },
    {
        id = "firefox",
        class_re = "^(firefox|Firefox)$",
        workspace = 3,
        classes = { "firefox", "Firefox" },
        cmd = "firefox",
    },
    {
        id = "zen",
        class_re = "^(zen|zen-browser|Zen|Zen-browser)$",
        workspace = 3,
        classes = { "zen", "zen-browser", "Zen", "Zen-browser" },
        cmd = "zen-browser",
    },
    {
        id = "yandex",
        class_re = "^[Yy]andex.?[Bb]rowser$",
        workspace = 4,
        classes = { "yandex-browser", "Yandex-browser" },
        cmd = home .. "/.local/bin/yandex-browser-stable",
    },
    {
        id = "chrome",
        class_re = "^(google-chrome|Google-chrome|chromium|Chromium|brave-browser|Brave-browser)$",
        workspace = 5,
        classes = {
            "google-chrome",
            "Google-chrome",
            "chromium",
            "Chromium",
            "brave-browser",
            "Brave-browser",
        },
        cmd = "google-chrome-stable",
    },
    {
        id = "claude",
        class_re = "^com\\.anthropic\\.Claude$",
        workspace = 2, -- C
        home_only = true, -- always C: ignore last-session workspace
        classes = { "com.anthropic.Claude" },
        cmd = "claude-desktop",
    },
    {
        id = "chatgpt",
        class_re = "^(Chatgpt|chatgpt|ChatGPT)$",
        workspace = 6,
        classes = { "Chatgpt", "chatgpt", "ChatGPT" },
        cmd = "chatgpt",
    },
    {
        id = "kitty",
        class_re = "^kitty$",
        workspace = 7,
        classes = { "kitty" },
        cmd = "/usr/bin/kitty",
    },
    {
        id = "nautilus",
        class_re = "^(org\\.gnome\\.Nautilus|Nautilus|nautilus)$",
        workspace = 8,
        classes = { "org.gnome.Nautilus", "Nautilus", "nautilus" },
        cmd = home .. "/.local/bin/nautilus-dark --new-window",
    },
    {
        id = "telegram",
        class_re = "^(org\\.telegram\\.desktop|TelegramDesktop)$",
        workspace = 9,
        classes = { "org.telegram.desktop", "TelegramDesktop" },
        cmd = home .. "/.local/bin/Telegram",
    },
    {
        id = "discord",
        class_re = "^(discord|Discord)$",
        workspace = 10,
        classes = { "discord", "Discord" },
        cmd = nil, -- no autostart / session restore; placement only
    },
    {
        id = "preview",
        class_re = "^(org\\.gnome\\.Evince|evince|org\\.gnome\\.Loupe|loupe|eog|org\\.kde\\.okular|okular|imv)$",
        workspace = 11,
        classes = {
            "org.gnome.Evince",
            "evince",
            "org.gnome.Loupe",
            "loupe",
            "eog",
            "org.kde.okular",
            "okular",
            "imv",
        },
        cmd = nil,
    },
    {
        id = "spotify",
        class_re = "^(spotify|Spotify)$",
        workspace = 13,
        classes = { "spotify", "Spotify" },
        cmd = "spotify-launcher --skip-update",
    },
    {
        id = "zoom",
        class_re = "^(zoom|Zoom)$",
        workspace = 14,
        classes = { "zoom", "Zoom" },
        cmd = os.getenv("HOME") .. "/.config/hypr/scripts/zoom.sh",
    },
    {
        id = "obs",
        class_re = "^(com\\.obsproject\\.Studio|obs)$",
        workspace = 14,
        classes = { "com.obsproject.Studio", "obs" },
        cmd = "obs --disable-shutdown-check",
    },
    {
        id = "obsidian",
        class_re = "^(obsidian|Obsidian)$",
        workspace = 15,
        classes = { "obsidian", "Obsidian" },
        cmd = "obsidian",
    },
    {
        id = "thunderbird",
        class_re = "^(thunderbird|Thunderbird|org\\.mozilla\\.Thunderbird)$",
        workspace = 16,
        classes = { "thunderbird", "Thunderbird", "org.mozilla.Thunderbird" },
        cmd = "thunderbird",
    },
}

M.by_id = {}
M.by_class = {}
M.by_class_lower = {}

for _, app in ipairs(M.catalog) do
    M.by_id[app.id] = app
    for _, class in ipairs(app.classes) do
        M.by_class[class] = app
        M.by_class_lower[string.lower(class)] = app
    end
end

function M.app_for_class(class)
    if not class or class == "" then
        return nil
    end
    return M.by_class[class] or M.by_class_lower[string.lower(class)]
end

local state_home = os.getenv("XDG_STATE_HOME")
if not state_home or state_home == "" then
    state_home = home .. "/.local/state"
end

M.state_dir = state_home .. "/hypr"
M.state_file = M.state_dir .. "/session-apps"
M.restoring_file = M.state_dir .. "/session-apps.restoring"

function M.entry_workspace(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" then
        return entry.ws
    end
    return nil
end

function M.entry_side(entry)
    if type(entry) == "table" then
        local side = entry.side
        if side == "L" or side == "R" or side == "A" then
            return side
        end
    end
    return "A"
end

-- Map keyed by app id (last row wins). Placement uses this.
function M.parse_snapshot(path)
    local targets = {}
    for _, row in ipairs(M.parse_snapshot_rows(path)) do
        targets[row.id] = { ws = row.ws, side = row.side }
    end
    return targets
end

-- All snapshot rows, including duplicate ids (two kitties, two Cursors, …).
function M.parse_snapshot_rows(path)
    local rows = {}
    local file = io.open(path or M.state_file, "r")
    if not file then
        return rows
    end
    for raw in file:lines() do
        local line = raw:gsub("\r$", "")
        local id, ws, side = line:match("^([a-z][a-z0-9_-]*)%s+(%d+)%s+([LRA])%s*$")
        if not id then
            id, ws = line:match("^([a-z][a-z0-9_-]*)%s+(%d+)%s*$")
            side = "A"
        end
        if id and ws then
            local n = tonumber(ws)
            if n and n >= 1 and n <= 16 and M.by_id[id] then
                rows[#rows + 1] = { id = id, ws = n, side = side or "A" }
            end
        end
    end
    file:close()
    return rows
end

local function snapshot_rows_from(entries)
    local rows = {}
    if type(entries) ~= "table" then
        return rows
    end
    if entries[1] and type(entries[1]) == "table" and entries[1].id then
        for _, row in ipairs(entries) do
            local ws = M.entry_workspace(row) or row.ws
            if row.id and ws then
                rows[#rows + 1] = { id = row.id, ws = ws, side = M.entry_side(row) }
            end
        end
        return rows
    end
    for id, entry in pairs(entries) do
        local ws = M.entry_workspace(entry)
        if type(id) == "string" and ws then
            rows[#rows + 1] = { id = id, ws = ws, side = M.entry_side(entry) }
        end
    end
    return rows
end

function M.format_snapshot(entries)
    local rows = snapshot_rows_from(entries)
    table.sort(rows, function(a, b)
        if a.id ~= b.id then
            return a.id < b.id
        end
        if a.ws ~= b.ws then
            return a.ws < b.ws
        end
        return (a.side or "A") < (b.side or "A")
    end)
    local chunks = { "# session-apps: id workspace side\n" }
    for _, row in ipairs(rows) do
        chunks[#chunks + 1] = string.format("%s %d %s\n", row.id, row.ws, row.side)
    end
    return table.concat(chunks)
end

function M.snapshot_row_count(entries)
    return #snapshot_rows_from(entries)
end

function M.ensure_state_dir()
    os.execute("mkdir -p '" .. M.state_dir:gsub("'", "'\\''") .. "'")
end

function M.restoring_flag_present()
    local file = io.open(M.restoring_file, "r")
    if not file then
        return false
    end
    local first = file:read("*l")
    file:close()
    local ts = tonumber(first)
    -- Empty leftover from an old `touch`, or timestamp older than 2 minutes.
    -- hyprctl reload kills the Lua cleanup timer; drop the file so saves resume.
    if not ts or (os.time() and (os.time() - ts) > 120) then
        pcall(os.remove, M.restoring_file)
        return false
    end
    return true
end

return M
