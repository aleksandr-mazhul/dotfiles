import QtQuick
import QtQuick.Layouts
import Quickshell

RicePanel {
    id: root

    property var apps: []
    property var filtered: []

    title: "Applications"
    searchPlaceholder: "Search apps…"
    footerText: "↑↓ move  ·  ↵ launch  ·  esc close"
    model: filtered
    countText: filtered.length + (filtered.length === 1 ? " app" : " apps")
    maxVisible: 9

    Component.onCompleted: loadApps()
    onPanelOpened: {
        loadApps()
        applyFilter()
    }
    onQueryChanged: applyFilter()
    onActivated: (item, index) => {
        close()
        if (item && item.execute)
            item.execute()
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

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q) {
            filtered = apps.slice()
        } else {
            filtered = apps.filter(app => {
                const name = (app.name || "").toLowerCase()
                const generic = (app.genericName || "").toLowerCase()
                const keywords = (app.keywords || []).join(" ").toLowerCase()
                return name.includes(q) || generic.includes(q) || keywords.includes(q)
            })
        }
        clampSelection()
    }

    rowDelegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: Theme.rowHeight
        radius: Theme.radiusSm
        color: index === root.selectedIndex ? Theme.primary : Theme.surfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            Image {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: modelData.name || modelData.id
                    color: index === root.selectedIndex ? Theme.onPrimary : Theme.onSurface
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: !!(modelData.genericName && modelData.genericName.length)
                    text: modelData.genericName || ""
                    color: index === root.selectedIndex ? Theme.onPrimary : Theme.outline
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    elide: Text.ElideRight
                    opacity: 0.85
                }
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
