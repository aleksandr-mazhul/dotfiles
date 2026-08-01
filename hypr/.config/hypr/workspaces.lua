-- Workspace display names (letters match Alt+letter binds)

local names = { "W", "E", "T", "D", "Z", "X", "C", "Q", "B", "U" }

for i, name in ipairs(names) do
    hl.workspace_rule({
        workspace = i,
        default_name = name,
    })
end
