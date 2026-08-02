-- hypr-dynamic-cursors — Mac-like "shake to find".
-- Fast enlarge on shake; smooth shrink when you stop.

hl.config({
    plugin = {
        dynamic_cursors = {
            enabled = true,
            mode = "none",
            shake = {
                enabled = true,
                threshold = 3.0,
                base = 2.5,
                speed = 0.0,
                influence = 0.0,
                limit = 2.5,
                -- brief hold, then smooth shrink (animation patched in plugin ~250ms)
                timeout = 120,
                effects = false,
                ipc = false,
            },
            hyprcursor = {
                nearest = 2,
                enabled = true,
                resolution = -1,
                fallback = "left_ptr",
            },
        },
    },
})
