import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Raycast-style hub: built-in commands (Clipboard / Wallpapers / VPN) + apps.
// Dedicated hotkeys still open each overlay directly.
RicePanel {
    id: root

    property var commands: []
    property var apps: []
    property var filtered: []
    property int savedLayoutIndex: -1
    property string kbDevice: ""

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
        buildCommands()
        loadApps()
        applyFilter()
        layoutCaptureProc.running = true
    }
    onPanelClosed: restoreLayout()
    onQueryChanged: applyFilter()
    onActivated: (item, index) => {
        const action = item && item.kind === "command"
            ? item.action
            : (item && item.execute ? () => item.execute() : null)
        close()
        if (action)
            Qt.callLater(action)
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
                shortcut: "Ctrl+Q",
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

    // Force English (us) while searching; restore previous layout on close.
    function restoreLayout() {
        if (savedLayoutIndex < 0 || !kbDevice)
            return
        layoutSwitchProc.exec(["hyprctl", "switchxkblayout", kbDevice, String(savedLayoutIndex)])
        savedLayoutIndex = -1
        kbDevice = ""
    }

    Process {
        id: layoutCaptureProc
        command: ["bash", "-c",
            "hyprctl devices -j | python3 -c '"
            + "import json,sys; "
            + "devs=json.load(sys.stdin); "
            + "kbs=devs.get(\"keyboards\") or []; "
            + "kb=next((k for k in kbs if k.get(\"main\")), None) or (kbs[0] if kbs else None); "
            + "sys.exit(0) if not kb else None; "
            + "layouts=[x.strip() for x in (kb.get(\"layout\") or \"us\").split(\",\") if x.strip()]; "
            + "us=next((i for i,l in enumerate(layouts) if l==\"us\" or l.startswith(\"us\")), 0); "
            + "print(kb.get(\"name\",\"\")); "
            + "print(int(kb.get(\"active_layout_index\", 0))); "
            + "print(int(us))"
            + "'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                if (lines.length < 3 || !lines[0])
                    return
                root.kbDevice = lines[0]
                root.savedLayoutIndex = parseInt(lines[1], 10)
                const usIdx = parseInt(lines[2], 10)
                if (isNaN(root.savedLayoutIndex) || isNaN(usIdx) || !root.kbDevice) {
                    root.savedLayoutIndex = -1
                    root.kbDevice = ""
                    return
                }
                if (root.savedLayoutIndex !== usIdx)
                    layoutSwitchProc.exec(["hyprctl", "switchxkblayout", root.kbDevice, String(usIdx)])
            }
        }
    }

    Process { id: layoutSwitchProc }

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
