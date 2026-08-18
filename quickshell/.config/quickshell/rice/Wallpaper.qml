import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RicePanel {
    id: root

    property var walls: []
    property var filtered: []
    property var markedPaths: []
    property string wallDir: Quickshell.env("HOME") + "/pictures/wallpapers"
    property string categoryFilter: "all"

    title: "Wallpapers"
    searchPlaceholder: "Search wallpapers…"
    footerText: "↑↓ move  ·  ⇧↵ mark  ·  ↵ apply  ·  ⌃P filter  ·  esc close"
    model: filtered
    countText: countLabel()
    itemHeight: 76
    maxVisible: 7
    panelHeight: 560
    filterValue: categoryFilter
    filterPlaceholder: "All"

    onPanelOpened: {
        markedPaths = []
        categoryFilter = "all"
        filterValue = "all"
        refresh.running = true
    }
    onPanelClosed: {
        markedPaths = []
        filterMenuOpen = false
    }
    onQueryChanged: applyFilter()
    onFilterChanged: value => {
        categoryFilter = value
        applyFilter()
    }
    onActivated: (item, index) => activatePrimary(item)

    customKeyHandler: event => {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ShiftModifier)) {
            toggleMarkAt(root.selectedIndex)
            return true
        }
        return false
    }

    function countLabel() {
        const n = filtered.length
        const base = n + (n === 1 ? " image" : " images")
        if (markedPaths.length > 0)
            return base + "  ·  " + markedPaths.length + " marked"
        return base
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
        if (categoryFilter !== "all" && !cats[categoryFilter]) {
            categoryFilter = "all"
            filterValue = "all"
        }
    }

    function applyFilter() {
        let base = walls.slice()
        if (categoryFilter && categoryFilter !== "all") {
            const prefix = categoryFilter + "/"
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

    rowDelegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: 72
        radius: Theme.radiusSm
        color: index === root.selectedIndex ? Theme.rowSelected : Theme.row
        border.width: root.isMarked(modelData.path) ? 2 : 0
        border.color: Theme.secondary

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 56
                radius: Theme.radiusSm
                color: Qt.rgba(0, 0, 0, 0.35)
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    visible: root.isMarked(modelData.path)
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: 18
                    height: 18
                    radius: 9
                    color: Theme.secondary

                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: Theme.textOnAccent
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: modelData.name
                color: index === root.selectedIndex ? Theme.textOnAccent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideMiddle
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
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
