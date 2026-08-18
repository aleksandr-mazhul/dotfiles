import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "ds" as DS

// Launcher — the reference popup of the design system
// (~/projects/personal/desktop-design-system/components/launcher.md).
// Presentation is pure composition of ds/ building blocks; this file owns only
// data & behaviour: built-in commands, app list, scoring, focus-or-launch.
DS.SearchListPopup {
    id: root

    property var commands: []
    property var apps: []
    property var filtered: []
    // Candidates awaiting Exec-binary existence check (id → entry).
    property var pendingApps: []
    // Coalesce applyFilter() so ListView.setModel is not called from a key
    // handler / QQmlBinding stack (Qt 6.11 SIGSEGV in QQmlIncubator).
    property int filterSeq: 0
    // normId(wayland appId / class) → 1, refreshed on open.
    property var runningNorm: ({})

    // Well-known products: the name is enough; genericName is marketing noise.
    readonly property var quietAppNames: ({
        "chatgpt": 1,
        "claude": 1,
        "obsidian": 1,
        "visual studio code": 1,
        "code - oss": 1,
        "code": 1,
        "cursor": 1,
        "zen browser": 1,
        "firefox": 1,
        "google chrome": 1,
        "chromium": 1,
        "discord": 1,
        "spotify": 1,
        "telegram": 1,
        "slack": 1,
        "steam": 1
    })

    // DE leftovers / service browsers / helper stubs that aren't useful as
    // top-level launcher icons on Hyprland. Keep real apps + rice commands.
    readonly property var junkAppIds: ({
        "xfce4-about": 1,
        "avahi-discover": 1,
        "bssh": 1,
        "bvnc": 1,
        "xgps": 1,
        "xgpsspeed": 1,
        "lstopo": 1,
        "uuctl": 1,
        "qv4l2": 1,
        "qvidcap": 1,
        "thunar": 1,
        "thunar-settings": 1,
        "thunar-bulk-rename": 1,
        "org.kde.dolphin": 1,
        "com.system76.CosmicFiles": 1,
        "io.elementary.files": 1,
        "cups": 1  // CUPS web UI duplicate of system-config-printer
    })

    placeholder: "Search apps & commands…"
    hintKeys: ["alt", "O"]
    model: filtered
    maxRows: 8
    surfaceWidth: 960

    Component.onCompleted: {
        buildCommands()
        loadApps()
    }
    onPopupOpened: {
        // EN for search typing; restore previous layout on close.
        // eh-layout-sync keeps Ergohaven firmware in step with Hyprland.
        Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/launcher-layout.sh open"])
        refreshRunning()
        buildCommands()
        loadApps()
        applyFilter()
    }
    onPopupClosed: {
        Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/launcher-layout.sh close"])
    }
    onSearchTextChanged: applyFilter()
    onActivated: (item, index) => {
        recordUsage(item)
        let action = null
        if (item && item.kind === "command")
            action = item.action
        else if (item)
            action = () => focusOrLaunch(item)
        // Instant close, then run action (no close-anim wait).
        close()
        if (typeof action === "function")
            action()
    }

    // Launch frecency — not in git; Quickshell.stateDir is per-machine.
    property FileView usageFile: FileView {
        path: `${Quickshell.stateDir}/launcher-usage.json`
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        adapter: JsonAdapter {
            id: usageAdapter
            property var launches: ({})
        }
    }

    // One-shot: drop entries whose Exec binary is missing from PATH / disk.
    Process {
        id: binCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const missing = {}
                const rows = text.split("\n")
                for (let i = 0; i < rows.length; i++) {
                    const id = rows[i].trim()
                    if (id)
                        missing[id] = 1
                }
                const kept = []
                const pending = root.pendingApps || []
                for (let i = 0; i < pending.length; i++) {
                    const e = pending[i]
                    const id = root.appIdKey(e)
                    if (!missing[id])
                        kept.push(e)
                }
                root.pendingApps = []
                kept.sort((a, b) => (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }))
                root.apps = kept
                root.applyFilter()
            }
        }
    }

    function copyStrList(v) {
        const out = []
        if (!v)
            return out
        try {
            for (let i = 0; i < v.length; i++)
                out.push(String(v[i]))
        } catch (e) {}
        return out
    }

    // Plain JS only — ListView must not hold live DesktopEntry QObjects.
    // Quickshell replaces those entries and Qt 6.11 then SIGSEGVs in the incubator.
    function snapshotApp(e) {
        if (!e)
            return null
        return {
            id: String(e.id || ""),
            name: String(e.name || ""),
            genericName: String(e.genericName || ""),
            comment: String(e.comment || ""),
            icon: String(e.icon || ""),
            startupClass: String(e.startupClass || ""),
            execString: String(e.execString || ""),
            runInTerminal: !!e.runInTerminal,
            command: copyStrList(e.command),
            keywords: copyStrList(e.keywords),
            categories: copyStrList(e.categories)
        }
    }

    function findDesktopEntry(id) {
        const raw = String(id || "").trim()
        if (!raw)
            return null
        const key = appIdKey({ id: raw })
        const entries = DesktopEntries.applications.values || []
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            if (!e)
                continue
            if (String(e.id || "").trim() === raw)
                return e
            if (key && appIdKey(e) === key)
                return e
        }
        return null
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

    function appIdKey(entry) {
        let id = String(entry && entry.id ? entry.id : "").trim()
        if (!id)
            return ""
        // Nested wine paths → basename; strip trailing .desktop
        const slash = id.lastIndexOf("/")
        if (slash >= 0)
            id = id.slice(slash + 1)
        return id.replace(/\.desktop$/i, "").toLowerCase()
    }

    function usageKey(entry) {
        if (!entry)
            return ""
        if (entry.kind === "command")
            return "cmd:" + String(entry.id || entry.name || "")
        return appIdKey(entry) || String(entry.name || "").toLowerCase()
    }

    function recordUsage(entry) {
        const key = usageKey(entry)
        if (!key)
            return
        const table = Object.assign({}, (usageAdapter && usageAdapter.launches) ? usageAdapter.launches : {})
        const prev = table[key] || {}
        table[key] = {
            count: (prev.count || 0) + 1,
            last: Date.now()
        }
        usageAdapter.launches = table
    }

    function refreshRunning() {
        const map = {}
        try {
            if (Hyprland.refreshToplevels)
                Hyprland.refreshToplevels()
        } catch (e) {}
        const tops = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i]
            const appId = normId(t.wayland ? t.wayland.appId : "")
            if (appId)
                map[appId] = 1
            try {
                const ipc = t.lastIpcObject || {}
                const cls = normId(ipc.class || ipc.initialClass || "")
                if (cls)
                    map[cls] = 1
            } catch (e) {}
        }
        runningNorm = map
    }

    function isRunning(entry) {
        const hints = appHints(entry)
        const map = runningNorm || {}
        for (let i = 0; i < hints.length; i++) {
            if (hints[i] && map[hints[i]])
                return true
        }
        return false
    }

    function usageScore(entry) {
        const key = usageKey(entry)
        const table = (usageAdapter && usageAdapter.launches) ? usageAdapter.launches : {}
        const rec = (key && table[key]) ? table[key] : null
        const count = rec && rec.count ? rec.count : 0
        const last = rec && rec.last ? rec.last : 0
        const ageH = last > 0 ? Math.max(0, (Date.now() - last) / 3600000) : 1e6
        // Half-life ~14 days: last week counts almost fully, last month less.
        const recency = last > 0 ? Math.pow(0.5, ageH / (14 * 24)) : 0
        const freq = Math.log(1 + count)
        const running = isRunning(entry) ? 0.45 : 0
        return freq * (0.35 + 0.65 * recency) + running
    }

    function fieldTight(text, q) {
        if (!text || !q)
            return 99
        const lower = String(text).toLowerCase()
        if (lower === q)
            return 0
        if (lower.startsWith(q))
            return Math.min(lower.length - q.length, 20)
        const words = wordTokens(text)
        let best = 99
        for (let i = 0; i < words.length; i++) {
            const t = words[i].toLowerCase()
            if (t === q)
                return 0
            if (t.startsWith(q))
                best = Math.min(best, Math.min(t.length - q.length, 20))
        }
        return best
    }

    function execBinary(entry) {
        const cmd = entry && entry.command
        if (!cmd || !cmd.length)
            return ""
        let i = 0
        // Desktop entries sometimes wrap with `env VAR=val …`
        if (String(cmd[0]) === "env") {
            i = 1
            while (i < cmd.length && String(cmd[i]).indexOf("=") >= 0)
                i++
        }
        // flatpak run … — treat flatpak itself as the binary
        if (i >= cmd.length)
            return ""
        return String(cmd[i])
    }

    function isJunkApp(entry) {
        if (!entry || entry.noDisplay)
            return true

        const bin = execBinary(entry)
        if (!bin && !(entry.execString && String(entry.execString).trim()))
            return true

        const cats = entry.categories || []
        for (let i = 0; i < cats.length; i++) {
            if (cats[i] === "Screensaver")
                return true
        }

        const id = appIdKey(entry)
        if (id && junkAppIds[id])
            return true

        // Wine uninstallers / leftover helpers that sometimes slip past NoDisplay
        const name = String(entry.name || "").toLowerCase()
        if (name.indexOf("uninstall") >= 0)
            return true
        if (id.indexOf("wine-") === 0 || id.indexOf("wine_") === 0)
            return true

        return false
    }

    function rowDescription(entry) {
        if (!entry)
            return ""
        const generic = String(entry.genericName || "").trim()
        if (!generic)
            return ""
        if (entry.kind === "command")
            return generic
        const lower = String(entry.name || "").trim().toLowerCase()
        if (!lower)
            return generic
        if (root.quietAppNames[lower])
            return ""
        const keys = [
            "chatgpt", "claude", "obsidian", "visual studio code",
            "code - oss", "code", "cursor", "zen browser", "firefox",
            "google chrome", "chromium", "discord", "spotify",
            "telegram", "slack", "steam"
        ]
        for (let i = 0; i < keys.length; i++) {
            if (lower.indexOf(keys[i]) === 0)
                return ""
        }
        if (lower === generic.toLowerCase())
            return ""
        return generic
    }

    function launchEntry(entry) {
        if (!entry)
            return

        // DesktopEntry.execute() currently ignores runInTerminal — wrap ourselves.
        if (entry.runInTerminal && entry.command && entry.command.length) {
            const term = Quickshell.env("TERMINAL") || "kitty"
            Quickshell.execDetached([term, "-e"].concat(entry.command.slice()))
            return
        }

        // Snapshots are plain JS — look up the live DesktopEntry so DBusActivatable
        // / field-code execute() still works when the cache has not dropped it.
        const live = findDesktopEntry(entry.id)
        if (live && live.execute) {
            try {
                live.execute()
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
        // Chrome icons: our own mono glyph set (foundation/icons.md) — commands are
        // system chrome, so they never use random theme icons.
        commands = [
            {
                kind: "command",
                id: "clipboard",
                name: "Clipboard History",
                genericName: "Paste from clipboard history",
                keywords: ["clipboard", "clip", "paste", "буфер", "история"],
                monoIcon: "cmd-clipboard.svg",
                shortcutKeys: ["super", "Q"],
                action: () => OverlayHub.open("clipboard")
            },
            {
                kind: "command",
                id: "wallpaper",
                name: "Wallpapers",
                genericName: "Browse and apply wallpapers",
                keywords: ["wallpaper", "wall", "фон", "обои", "theme"],
                monoIcon: "cmd-wallpaper.svg",
                shortcutKeys: ["super", "W"],
                action: () => OverlayHub.open("wallpaper")
            },
            {
                kind: "command",
                id: "vpn",
                name: "VPN",
                genericName: "Connect or switch VPN location",
                keywords: ["vpn", "mullvad", "wireguard", "proxy"],
                monoIcon: "cmd-vpn.svg",
                shortcutKeys: ["super", "V"],
                action: () => OverlayHub.open("vpn")
            }
        ]
    }

    function loadApps() {
        // DesktopEntries.applications already excludes Hidden/NoDisplay.
        const entries = DesktopEntries.applications.values || []
        const list = []
        const checkArgs = [
            "python3", "-c",
            "import os, shutil, sys\n" +
            "args = sys.argv[1:]\n" +
            "for i in range(0, len(args), 2):\n" +
            "    eid, bin = args[i], args[i+1]\n" +
            "    if not bin:\n" +
            "        print(eid); continue\n" +
            "    if '/' in bin:\n" +
            "        ok = os.path.isfile(bin) and os.access(bin, os.X_OK)\n" +
            "    else:\n" +
            "        ok = shutil.which(bin) is not None\n" +
            "    if not ok:\n" +
            "        print(eid)\n"
        ]

        for (let i = 0; i < entries.length; i++) {
            const e = entries[i]
            if (isJunkApp(e))
                continue
            const snap = snapshotApp(e)
            if (!snap)
                continue
            list.push(snap)
            const id = appIdKey(snap)
            const bin = execBinary(snap)
            if (id)
                checkArgs.push(id, bin || "")
        }

        // Show filtered list immediately; refine once binary check finishes.
        list.sort((a, b) => (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }))
        apps = list
        pendingApps = list.slice()

        if (list.length === 0) {
            applyFilter()
            return
        }

        binCheck.running = false
        binCheck.command = checkArgs
        binCheck.running = true
    }

    function isWordBoundary(text, i) {
        if (i <= 0)
            return true
        const prev = text[i - 1]
        const curr = text[i]
        return /[\s\-_.+/]/.test(prev)
            || (/[a-z0-9]/.test(prev) && /[A-Z]/.test(curr))
    }

    function wordTokens(text) {
        return String(text || "").split(/[\s\-_.+/]+/).filter(t => t.length > 0)
    }

    function initialsOf(text) {
        const s = String(text || "")
        let ini = ""
        for (let i = 0; i < s.length; i++) {
            if (/[A-Za-z0-9]/.test(s[i]) && isWordBoundary(s, i))
                ini += s[i].toLowerCase()
        }
        return ini
    }

    function keywordList(entry) {
        const kw = entry && entry.keywords
        if (!kw)
            return []
        const raw = Array.isArray(kw) ? kw : [kw]
        const out = []
        for (let i = 0; i < raw.length; i++) {
            const parts = String(raw[i]).split(/[;,]/)
            for (let j = 0; j < parts.length; j++) {
                const t = parts[j].trim()
                if (t)
                    out.push(t)
            }
        }
        return out
    }

    function idFields(entry) {
        const fields = []
        const push = (s) => {
            const t = String(s || "").trim()
            if (t && fields.indexOf(t) < 0)
                fields.push(t)
        }
        const skip = { org: 1, com: 1, io: 1, net: 1, desktop: 1, www: 1 }
        const id = String(entry && entry.id ? entry.id : "")
        const parts = id.split(/[./]/)
        // Skip reverse-domain prefixes so "co" does not match com.anthropic.*
        if (parts.length <= 1)
            push(id)
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] && !skip[parts[i].toLowerCase()])
                push(parts[i])
        }
        push(entry && entry.startupClass)
        const bin = execBinary(entry)
        if (bin)
            push(String(bin).split("/").pop())
        return fields
    }

    function fieldScore(text, q) {
        if (!text || !q)
            return 0
        const raw = String(text)
        const lower = raw.toLowerCase()
        if (lower === q)
            return 100

        let best = 0
        const tightPrefix = (str, base) => {
            const s = String(str).toLowerCase()
            if (s === q)
                return Math.max(base, 96)
            if (!s.startsWith(q))
                return 0
            return base
        }

        best = Math.max(best, tightPrefix(lower, 92))

        const words = wordTokens(raw)
        for (let i = 0; i < words.length; i++)
            best = Math.max(best, tightPrefix(words[i], 92))

        const idx = lower.indexOf(q)
        if (idx > 0) {
            if (isWordBoundary(raw, idx))
                best = Math.max(best, 86 - Math.min(idx, 20))
            else if (q.length >= 3)
                best = Math.max(best, Math.max(1, 45 - Math.min(idx, 40)))
        }

        if (q.length >= 2) {
            const ini = initialsOf(raw)
            if (ini === q)
                best = Math.max(best, 74)
            else if (ini.startsWith(q))
                best = Math.max(best, 68)
        }
        return best
    }

    function entryScore(entry, q) {
        const n = fieldScore(entry.name || "", q)
        const g = fieldScore(entry.genericName || "", q)
        const c = fieldScore(entry.comment || "", q)

        let k = 0
        const kws = keywordList(entry)
        for (let i = 0; i < kws.length; i++)
            k = Math.max(k, fieldScore(kws[i], q))

        let idScore = 0
        if (entry.kind === "command") {
            idScore = fieldScore(entry.id || "", q)
        } else {
            const ids = idFields(entry)
            for (let i = 0; i < ids.length; i++)
                idScore = Math.max(idScore, fieldScore(ids[i], q))
        }

        if (!n && !g && !k && !idScore && !c)
            return 0
        return Math.max(n * 100, idScore * 55, g * 40, k * 40, c * 12)
    }

    function applyFilter() {
        filterSeq += 1
        const seq = filterSeq
        Qt.callLater(() => {
            if (seq !== root.filterSeq)
                return
            root.applyFilterNow()
        })
    }

    function applyFilterNow() {
        const q = searchText.trim().toLowerCase()
        if (q) {
            // Lock hover before swapping the model so a rebuilt row under the
            // cursor cannot steal the top (best) match.
            keyboardNav = true
            navPointer = Qt.point(-1, -1)
        }
        if (!q) {
            // Sections per List Pattern: quiet labels, no boxes (ref #8 naming).
            let out = []
            if (commands.length)
                out = out.concat([{ kind: "header", label: "Suggestions" }], commands)
            if (apps.length)
                out = out.concat([{ kind: "header", label: "Applications" }], apps)
            filtered = out
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
                // Same matched-letter quality → more used / more recent first.
                const ua = usageScore(a.entry)
                const ub = usageScore(b.entry)
                if (ub !== ua)
                    return ub - ua
                const ta = fieldTight(a.entry.name || "", q)
                const tb = fieldTight(b.entry.name || "", q)
                if (ta !== tb)
                    return ta - tb
                const ac = a.entry.kind === "command" ? 1 : 0
                const bc = b.entry.kind === "command" ? 1 : 0
                if (bc !== ac)
                    return bc - ac
                const al = String(a.entry.name || "").length
                const bl = String(b.entry.name || "").length
                if (al !== bl)
                    return al - bl
                return (a.entry.name || "").localeCompare(b.entry.name || "", undefined, { sensitivity: "base" })
            })
            filtered = scored.map(x => x.entry)
        }
    }

    rowDelegate: Item {
        id: rowItem
        required property var modelData
        required property int index

        readonly property bool isHeader: !!(modelData && modelData.kind === "header")
        readonly property bool isCommand: !!(modelData && modelData.kind === "command")

        width: ListView.view ? ListView.view.width : 0
        height: isHeader ? DS.Tokens.sectionHeight : DS.Tokens.rowHeight

        DS.Hairline {
            visible: rowItem.isHeader && String(rowItem.modelData.label || "").toLowerCase() === "applications"
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: DS.Tokens.rowPaddingX
            anchors.rightMargin: DS.Tokens.rowPaddingX
            anchors.top: parent.top
            anchors.topMargin: 4
        }

        DS.SectionLabel {
            visible: rowItem.isHeader
            anchors.left: parent.left
            anchors.leftMargin: DS.Tokens.rowPaddingX
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            label: rowItem.isHeader ? (rowItem.modelData.label || "") : ""
        }

        DS.ListRow {
            visible: !rowItem.isHeader
            anchors.fill: parent
            primary: rowItem.isHeader ? "" : (rowItem.modelData.name || rowItem.modelData.id || "")
            secondary: rowItem.isHeader ? "" : (rowItem.modelData.genericName || "")
            trailingKeys: rowItem.isCommand ? (rowItem.modelData.shortcutKeys || []) : []
            chevron: !rowItem.isHeader && !rowItem.isCommand
            selected: rowItem.index === root.selectedIndex
            hoverActive: !root.keyboardNav
            onEntered: root.selectedIndex = rowItem.index
            onActivated: {
                root.selectedIndex = rowItem.index
                root.activateSelected()
            }

            // Commands are chrome → our mono glyph set; apps are content → their
            // own (possibly colorful) icons, falling back to our glyph.
            leading: rowItem.isCommand ? cmdIcon : appIconSlot
        }

        Component {
            id: cmdIcon
            Item {
                RiceIcon {
                    anchors.centerIn: parent
                    customSource: Qt.resolvedUrl("assets/" + (rowItem.modelData.monoIcon || "app-fallback.svg"))
                    tint: DS.Tokens.textIcon
                    implicitSize: 22
                    halo: true
                    haloColor: DS.Tokens.iconHalo
                }
            }
        }

        Component {
            id: appIconSlot
            Item {
                Image {
                    id: appIcon
                    anchors.fill: parent
                    source: rowItem.isHeader
                        ? ""
                        : Quickshell.iconPath(rowItem.modelData.icon, "application-x-executable")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    visible: status !== Image.Error
                }

                RiceIcon {
                    anchors.fill: parent
                    visible: appIcon.status === Image.Error
                    customSource: Qt.resolvedUrl("assets/app-fallback.svg")
                    tint: DS.Tokens.textSecondary
                    implicitSize: DS.Tokens.leadingSize
                }
            }
        }
    }
}
