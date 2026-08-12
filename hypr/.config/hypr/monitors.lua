-- Mirrors monitors.conf (nwg-displays). Explicit outputs only — no empty
-- "preferred" fallback that can force 60 Hz on DP-3.

hl.monitor({
    output = "DP-2",
    mode = "1920x1080@165.0",
    position = "0x0",
    scale = 1,
    transform = 1,
})

hl.monitor({
    output = "DP-3",
    mode = "2560x1440@164.8",
    position = "1080x480",
    scale = 1.25,
})
