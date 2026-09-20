import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "ds" as DS

DS.SearchListChrome {
    id: root

    property var walls: []
    property var filtered: []
    property var markedPaths: []
    property string transitionMode: "random"
    property string wallDir: Quickshell.env("HOME") + "/pictures/wallpapers"
    filterValue: "all"
    filterOptions: [{ value: "all", label: "All" }]

    pageId: "wallpaper"
    placeholder: "Search wallpapers…"
    hintKeys: ["super", "W"]
    model: filtered
    maxRows: 8
    rowSize: DS.Tokens.rowHeight
    closeHint: (host && host.canPop)
        ? ({ keys: ["esc"], label: "Back" })
        : ({ keys: ["esc"], label: "Close" })
    readonly property string applyHintLabel: markedPaths.length > 0
        ? ("Apply " + markedPaths.length)
        : "Apply"

    footerHints: [
        { keys: ["↑", "↓"], label: "Navigate" },
        { keys: ["⇧", "⏎"], label: "Mark" },
        { keys: ["⌃", "T"], label: "Anim: " + transitionMode },
        { keys: ["⏎"], label: applyHintLabel }
    ]

    onPageEntered: {
        markedPaths = []
        filterValue = "all"
        refresh.running = true
        modeGet.running = true
    }
    onPageLeft: markedPaths = []
    onSearchTextChanged: applyFilter()
    onFilterChanged: applyFilter()
    onActivated: (item, index) => activatePrimary(item)

    customKeyHandler: event => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            toggleMarkAt(root.selectedIndex)
            return true
        }
        if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)
                && !(event.modifiers & (Qt.ShiftModifier | Qt.AltModifier | Qt.MetaModifier))) {
            modeCycle.exec(["wallpaper-transition", "cycle"])
            return true
        }
        return false
    }

    function rebuildFilterOptions() {
        const cats = {}
        for (let i = 0; i < walls.length; i++) {
            const name = walls[i].name || ""
            const slash = name.indexOf("/")
            if (slash > 0)
                cats[name.slice(0, slash)] = true
        }
        const keys = Object.keys(cats).sort()
        const opts = [{ value: "all", label: "All" }]
        for (let i = 0; i < keys.length; i++)
            opts.push({ value: keys[i], label: keys[i] })
        filterOptions = opts
        if (filterValue !== "all" && !cats[filterValue]) {
            filterValue = "all"
            applyFilter()
        }
    }

    function applyFilter() {
        let base = walls.slice()
        if (filterValue && filterValue !== "all") {
            const prefix = filterValue + "/"
            base = base.filter(w => (w.name || "").startsWith(prefix))
        }
        const q = searchText.trim().toLowerCase()
        if (q)
            base = base.filter(w => (w.name || "").toLowerCase().includes(q))
        filtered = base
        clampSelection()
    }

    function isMarked(path) {
        return markedPaths.indexOf(path) >= 0
    }

    function toggleMarkAt(index) {
        if (!filtered || index < 0 || index >= filtered.length)
            return
        const item = filtered[index]
        if (!item || !item.path)
            return
        const path = item.path
        const idx = markedPaths.indexOf(path)
        let next
        if (idx >= 0) {
            next = markedPaths.slice()
            next.splice(idx, 1)
        } else {
            next = markedPaths.concat([path])
        }
        markedPaths = next
    }

    function activatePrimary(item) {
        if (markedPaths.length > 0) {
            applyBatch(markedPaths.slice())
            return
        }
        applyWallpaper(item)
    }

    function applyWallpaper(item) {
        if (!item || !item.path)
            return
        close()
        applyProc.exec([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs-apply-wallpaper.sh",
            item.path
        ])
    }

    function applyBatch(paths) {
        if (!paths || paths.length === 0)
            return
        close()
        const args = [
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs-apply-wallpaper.sh"
        ].concat(paths)
        applyProc.exec(args)
    }

    Process {
        id: refresh
        command: [
            "bash", "-c",
            'find -L "$1" -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \\) 2>/dev/null | sort',
            "_",
            root.wallDir
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l.length > 0)
                const parsed = []
                const prefix = root.wallDir.replace(/\/$/, "") + "/"
                for (let i = 0; i < rows.length; i++) {
                    const path = rows[i]
                    let name = path.startsWith(prefix) ? path.slice(prefix.length) : path
                    parsed.push({ path: path, name: name })
                }
                root.walls = parsed
                root.rebuildFilterOptions()
                root.applyFilter()
            }
        }
    }

    Process { id: applyProc }

    Process {
        id: modeGet
        command: ["wallpaper-transition", "get"]
        stdout: StdioCollector {
            onStreamFinished: root.transitionMode = text.trim() || "random"
        }
    }

    Process {
        id: modeCycle
        stdout: StdioCollector {
            onStreamFinished: root.transitionMode = text.trim() || "random"
        }
    }

    rowDelegate: Item {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : 0
        height: root.rowSize

        readonly property bool selected: index === root.selectedIndex
        readonly property bool marked: root.isMarked(modelData.path)

        DS.SelectionPill {
            anchors.fill: parent
            hovered: rowMouse.containsMouse && !root.keyboardNav
            selected: parent.selected
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: DS.Tokens.rowPaddingX
            anchors.rightMargin: DS.Tokens.rowPaddingX
            spacing: DS.Tokens.gapInline

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 44
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.28)
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    // Decode small: the library holds hundreds of 4K files
                    sourceSize.width: 160
                    sourceSize.height: 96
                }

                Rectangle {
                    visible: marked
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 16
                    height: 16
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.18)

                    DS.QuietText {
                        anchors.centerIn: parent
                        text: "✓"
                        color: DS.Tokens.textPrimary
                        font.pixelSize: 10
                        fontBold: true
                    }
                }
            }

            DS.QuietText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: modelData.name
                color: DS.Tokens.textPrimary
                font.family: DS.Tokens.fontUi
                font.pixelSize: DS.Tokens.fontSize
                fontWeight: Font.Medium
                elide: Text.ElideMiddle
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: !root.keyboardNav
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: root.keyboardNav ? Qt.BlankCursor : Qt.PointingHandCursor
            onEntered: {
                if (root.keyboardNav)
                    return
                root.selectedIndex = index
            }
            onClicked: mouse => {
                root.selectedIndex = index
                if (mouse.modifiers & Qt.ShiftModifier || mouse.button === Qt.RightButton) {
                    root.toggleMarkAt(index)
                    return
                }
                root.activateSelected()
            }
        }
    }
}
