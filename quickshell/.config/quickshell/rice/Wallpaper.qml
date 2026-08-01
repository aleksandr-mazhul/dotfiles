import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RicePanel {
    id: root

    property var walls: []
    property var filtered: []
    property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    title: "Wallpapers"
    searchPlaceholder: "Search wallpapers…"
    footerText: "↑↓ move  ·  ↵ apply  ·  esc close"
    model: filtered
    countText: filtered.length + (filtered.length === 1 ? " image" : " images")
    itemHeight: 76
    maxVisible: 7
    panelWidth: 580
    panelMaxHeight: 560

    onPanelOpened: refresh.running = true
    onQueryChanged: applyFilter()
    onActivated: (item, index) => applyWallpaper(item)

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q)
            filtered = walls.slice()
        else
            filtered = walls.filter(w => (w.name || "").toLowerCase().includes(q))
        clampSelection()
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
        color: index === root.selectedIndex ? Theme.primary : Theme.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 56
                radius: Theme.radiusSm
                color: Qt.rgba(0, 0, 0, 0.25)
                clip: true

                Image {
                    anchors.fill: parent
                    source: "file://" + modelData.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
            }

            Text {
                Layout.fillWidth: true
                text: modelData.name
                color: index === root.selectedIndex ? Theme.onPrimary : Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideMiddle
            }
        }

        MouseArea {
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
