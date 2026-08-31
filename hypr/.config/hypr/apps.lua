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
        cmd = "webstorm",
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
        workspace = 6,
        classes = { "com.anthropic.Claude" },
        cmd = "claude",
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
        cmd = "kitty",
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
        cmd = home .. "/.local/bin/discord",
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
        cmd = "spotify",
    },
    {
        id = "zoom",
        class_re = "^(zoom|Zoom)$",
        workspace = 14,
        classes = { "zoom", "Zoom" },
        cmd = "/home/stranger/.config/hypr/scripts/zoom.sh",
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

function M.parse_snapshot(path)
    local targets = {}
    local file = io.open(path or M.state_file, "r")
    if not file then
        return targets
    end
    for line in file:lines() do
        local id, ws = line:match("^([a-z][a-z0-9_-]*)%s+(%d+)%s*$")
        if id and ws then
            local n = tonumber(ws)
            if n and n >= 1 and n <= 16 and M.by_id[id] then
                targets[id] = n
            end
        end
    end
    file:close()
    return targets
end

function M.format_snapshot(entries)
    local ids = {}
    for id in pairs(entries) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local chunks = { "# session-apps: id workspace\n" }
    for _, id in ipairs(ids) do
        chunks[#chunks + 1] = string.format("%s %d\n", id, entries[id])
    end
    return table.concat(chunks)
end

function M.ensure_state_dir()
    os.execute("mkdir -p '" .. M.state_dir:gsub("'", "'\\''") .. "'")
end

function M.restoring_flag_present()
    local file = io.open(M.restoring_file, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

return M
