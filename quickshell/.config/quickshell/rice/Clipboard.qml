import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RicePanel {
    id: root

    property var items: []
    property var filtered: []
    property string prevAddr: ""
    property string thumbDir: ""

    title: "Clipboard"
    searchPlaceholder: "Search history…"
    footerText: "↑↓ move  ·  ↵ paste  ·  esc close"
    itemHeight: 56
    maxVisible: 8
    model: filtered
    countText: filtered.length + (filtered.length === 1 ? " item" : " items")

    function refreshList() {
        captureFocus.running = true
        thumbs.running = true
        refresh.running = true
    }

    onPanelOpened: refreshList()
    onQueryChanged: applyFilter()
    onActivated: (item, index) => pasteItem(item)

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q)
            filtered = items.slice()
        else
            filtered = items.filter(it => (it.preview || "").toLowerCase().includes(q))
        clampSelection()
    }

    function pasteItem(item) {
        if (!item)
            return
        pasteProc.exec([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-paste-from-line.sh",
            item.line,
            prevAddr
        ])
        close()
    }

    function thumbPath(item) {
        if (!item || !item.isImage || !thumbDir || !item.id)
            return ""
        return "file://" + thumbDir + "/" + item.id + ".png"
    }

    Process {
        id: captureFocus
        command: ["bash", "-c", "hyprctl activewindow -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(\"address\",\"\"))'"]
        stdout: StdioCollector {
            onStreamFinished: root.prevAddr = text.trim()
        }
    }

    Process {
        id: thumbs
        command: ["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/clipboard-thumbs.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.thumbDir = text.trim()
                root.filtered = root.filtered.slice()
            }
        }
    }

    Process {
        id: refresh
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l.length > 0)
                const parsed = []
                for (let i = 0; i < rows.length; i++) {
                    const line = rows[i]
                    if (line.includes("hypr-clipboard-paste") || line.includes("file:///tmp/hypr-clipboard"))
                        continue
                    const tab = line.indexOf("\t")
                    const id = tab >= 0 ? line.slice(0, tab) : line
                    let preview = tab >= 0 ? line.slice(tab + 1) : line
                    const isImage = /\[\[\s*binary data/i.test(preview) || /image\//i.test(preview)
                    if (preview.length > 120)
                        preview = preview.slice(0, 117) + "…"
                    parsed.push({ id: id, line: line, preview: preview, isImage: isImage })
                }
                root.items = parsed
                root.applyFilter()
            }
        }
    }

    Process { id: pasteProc }

    rowDelegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: modelData.isImage ? 72 : Theme.rowHeight
        radius: Theme.radiusSm
        color: index === root.selectedIndex ? Theme.primary : Theme.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Rectangle {
                visible: modelData.isImage
                Layout.preferredWidth: 72
                Layout.preferredHeight: 56
                radius: Theme.radiusSm
                color: Qt.rgba(0, 0, 0, 0.25)
                clip: true

                Image {
                    id: thumb
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.thumbPath(modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: parent.visible && thumb.status !== Image.Ready
                    text: "IMG"
                    color: index === root.selectedIndex ? Theme.onPrimary : Theme.secondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.bold: true
                }
            }

            Text {
                visible: !modelData.isImage
                text: "•"
                color: index === root.selectedIndex ? Theme.onPrimary : Theme.secondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.bold: true
                Layout.preferredWidth: 18
            }

            Text {
                Layout.fillWidth: true
                text: modelData.preview
                color: index === root.selectedIndex ? Theme.onPrimary : Theme.onSurface
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                maximumLineCount: modelData.isImage ? 2 : 1
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
