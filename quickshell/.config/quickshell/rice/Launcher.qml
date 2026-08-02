import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Raycast-style hub: built-in commands (Clipboard / Wallpapers / VPN) + apps.
// Dedicated hotkeys still open each overlay directly.
RicePanel {
    id: root

    property var commands: []
    property var apps: []
    property var filtered: []

    title: "Launcher"
    searchPlaceholder: "Search apps & commands…"
    footerText: "↑↓ move  ·  ↵ open  ·  esc close"
    model: filtered
    countText: filtered.length + (filtered.length === 1 ? " result" : " results")
    maxVisible: 9

    Component.onCompleted: {
        buildCommands()
        loadApps()
    }
    onPanelOpened: {
        // EN for search typing; restore previous layout on close.
        // eh-layout-sync keeps Ergohaven firmware in step with Hyprland.
        Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/launcher-layout.sh open"])
        buildCommands()
        loadApps()
        applyFilter()
    }
    onPanelClosed: {
        Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/launcher-layout.sh close"])
    }
    onQueryChanged: applyFilter()
    onActivated: (item, index) => {
        let action = null
        if (item && item.kind === "command")
            action = item.action
        else if (item)
            action = () => focusOrLaunch(item)
        close()
        if (action)
            Qt.callLater(action)
    }

    function normId(s) {
        return String(s || "").toLowerCase().replace(/[^a-z0-9]+/g, "")
    }

    function appHints(entry) {
        const hints = []
        const push = (s) => {
            const n = normId(s)
            if (n && n.length >= 2 && hints.indexOf(n) < 0)
                hints.push(n)
        }
        push(entry.startupClass)
        push(entry.id)
        if (entry.id) {
            const parts = String(entry.id).split(".")
            const last = parts[parts.length - 1]
            if (last && last.toLowerCase() !== "desktop")
                push(last)
        }
        if (entry.command && entry.command.length)
            push(String(entry.command[0]).split("/").pop())
        return hints
    }

    // If the app is already open, jump to its workspace and focus it.
    function focusExisting(entry) {
        const hints = appHints(entry)
        if (!hints.length)
            return false

        try {
            if (Hyprland.refreshToplevels)
                Hyprland.refreshToplevels()
        } catch (e) {}

        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i]
            const appId = normId(t.wayland ? t.wayland.appId : "")
            let cls = ""
            try {
                const ipc = t.lastIpcObject || {}
                cls = normId(ipc.class || ipc.initialClass || "")
            } catch (e) {}

            // Skip transient/empty toplevels: hint.indexOf("") === 0 would
            // match every app and block launches.
            if (!appId && !cls)
                continue

            let hit = false
            for (let h = 0; h < hints.length; h++) {
                const hint = hints[h]
                if (!hint)
                    continue
                if (appId === hint || cls === hint) {
                    hit = true
                } else if (hint.length >= 4) {
                    // Only "window id contains hint" (not reverse): reverse
                    // plus empty ids falsely matched every launch.
                    if ((appId && appId.indexOf(hint) >= 0) || (cls && cls.indexOf(hint) >= 0))
                        hit = true
                    else if ((appId && appId.length >= 4 && hint.indexOf(appId) >= 0)
                          || (cls && cls.length >= 4 && hint.indexOf(cls) >= 0))
                        hit = true
                }
                if (hit)
                    break
            }
            if (!hit)
                continue

            if (t.workspace && t.workspace.activate)
                t.workspace.activate()
            if (t.wayland && t.wayland.activate)
                t.wayland.activate()
            else if (t.address)
                // Hyprland 0.56 Lua: classic `hyprctl dispatch` is broken.
                Quickshell.execDetached([
                    "hyprctl", "eval",
                    'hl.dispatch(hl.dsp.focus({ window = "address:' + t.address + '" }))'
                ])
            return true
        }
        return false
    }

    function launchEntry(entry) {
        if (!entry)
            return
        if (entry.execute) {
            try {
                entry.execute()
                return
            } catch (e) {}
        }
        // Fallback if DesktopEntries.execute is unavailable/broken.
        if (entry.command && entry.command.length)
            Quickshell.execDetached(entry.command.slice())
        else if (entry.execString)
            Quickshell.execDetached(["bash", "-lc", entry.execString])
    }

    function focusOrLaunch(entry) {
        if (focusExisting(entry))
            return
        launchEntry(entry)
    }

    function buildCommands() {
        // Easy to extend later — just push another entry.
        commands = [
            {
                kind: "command",
                id: "clipboard",
                name: "Clipboard History",
                genericName: "Paste from clipboard history",
                keywords: ["clipboard", "clip", "paste", "буфер", "история"],
                icon: "edit-paste",
                shortcut: "Super+Q",
                action: () => OverlayHub.open("clipboard")
            },
            {
                kind: "command",
                id: "wallpaper",
                name: "Wallpapers",
                genericName: "Browse and apply wallpapers",
                keywords: ["wallpaper", "wall", "фон", "обои", "theme"],
                icon: "preferences-desktop-wallpaper",
                shortcut: "Super+W",
                action: () => OverlayHub.open("wallpaper")
            },
            {
                kind: "command",
                id: "vpn",
                name: "VPN",
                genericName: "Connect or switch VPN location",
                keywords: ["vpn", "mullvad", "wireguard", "proxy"],
                icon: "network-vpn",
                shortcut: "Super+V",
                action: () => OverlayHub.open("vpn")
            }
        ]
    }

    function loadApps() {
        const entries = DesktopEntries.applications.values || []
        const list = []
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            if (!e || e.noDisplay)
                continue
            list.push(e)
        }
        list.sort((a, b) => (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }))
        apps = list
    }

    function fieldScore(text, q) {
        if (!text || !q)
            return 0
        const lower = text.toLowerCase()
        if (lower === q)
            return 100
        if (lower.startsWith(q))
            return 90

        let best = 0
        for (let i = 1; i <= lower.length - q.length; i++) {
            if (lower.slice(i, i + q.length) !== q)
                continue
            const prev = text[i - 1]
            const curr = text[i]
            const boundary = /[\s\-_.+/]/.test(prev)
                || (/[a-z0-9]/.test(prev) && /[A-Z]/.test(curr))
            const tier = boundary ? 80 : Math.max(1, 50 - Math.min(i, 40))
            if (tier > best)
                best = tier
        }
        return best
    }

    function entryScore(entry, q) {
        const n = fieldScore(entry.name || "", q)
        const g = fieldScore(entry.genericName || "", q)
        const kw = entry.keywords
            ? (Array.isArray(entry.keywords) ? entry.keywords.join(" ") : String(entry.keywords))
            : ""
        const k = fieldScore(kw, q)
        // Also match command id ("clip", "wall")
        const idScore = entry.kind === "command" ? fieldScore(entry.id || "", q) : 0
        if (!n && !g && !k && !idScore)
            return 0
        // Commands get a small boost so "w" → Wallpapers stays competitive.
        const boost = entry.kind === "command" ? 15 : 0
        return n * 100 + g * 10 + k + idScore * 50 + boost
    }

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q) {
            // Raycast-like: commands pinned on top, then apps.
            filtered = commands.concat(apps)
        } else {
            const scored = []
            const pool = commands.concat(apps)
            for (let i = 0; i < pool.length; i++) {
                const entry = pool[i]
                const s = entryScore(entry, q)
                if (s > 0)
                    scored.push({ entry: entry, score: s })
            }
            scored.sort((a, b) => {
                if (b.score !== a.score)
                    return b.score - a.score
                // Prefer commands on tie
                const ac = a.entry.kind === "command" ? 1 : 0
                const bc = b.entry.kind === "command" ? 1 : 0
                if (bc !== ac)
                    return bc - ac
                return (a.entry.name || "").localeCompare(b.entry.name || "", undefined, { sensitivity: "base" })
            })
            filtered = scored.map(x => x.entry)
        }
        clampSelection()
    }

    rowDelegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: Theme.rowHeight
        radius: Theme.radiusSm
        color: {
            if (index === root.selectedIndex)
                return Theme.rowSelected
            if (hover.containsMouse)
                return Theme.rowHover
            return Theme.row
        }

        readonly property bool isCommand: modelData && modelData.kind === "command"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Image {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                source: Quickshell.iconPath(modelData.icon, isCommand ? "applications-system" : "application-x-executable")
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: modelData.name || modelData.id
                        color: index === root.selectedIndex ? Theme.textOnAccent : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                    }

                    // Raycast-style shortcut hint for built-in commands
                    Text {
                        visible: isCommand && !!(modelData.shortcut && modelData.shortcut.length)
                        text: modelData.shortcut || ""
                        color: index === root.selectedIndex ? Theme.textOnAccent : Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        opacity: index === root.selectedIndex ? 0.85 : 1.0
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !!(modelData.genericName && modelData.genericName.length)
                    text: modelData.genericName || ""
                    color: index === root.selectedIndex ? Theme.textOnAccent : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                    opacity: index === root.selectedIndex ? 0.85 : 1.0
                }
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.selectedIndex = index
            onClicked: {
                root.selectedIndex = index
                root.activateSelected()
            }
        }
    }
}
