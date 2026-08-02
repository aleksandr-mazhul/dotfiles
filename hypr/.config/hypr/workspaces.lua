-- Workspace display names (letters match Alt+letter binds from Mac skhd/yabai)
-- Indices match macos/.config/yabai/scripts/spaces.sh WORKSPACE_MAP

local names = {
    "W", "C", "V", "D", "G", "X", "Z", "E",
    "T", "I", "P", "Q", "U", "Y", "R", "A",
}

for i, name in ipairs(names) do
    hl.workspace_rule({
        workspace = i,
        default_name = name,
    })
end
