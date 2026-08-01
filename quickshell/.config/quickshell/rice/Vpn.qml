import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RicePanel {
    id: root

    property var entries: []
    property var filtered: []
    property string statusText: "○ Checking…"
    property string statusRaw: ""
    property string locationsRaw: ""
    readonly property string helper: Quickshell.env("HOME") + "/.config/hypr/scripts/qs-vpn.sh"

    title: "VPN"
    searchPlaceholder: "Search locations…"
    footerText: "↑↓ move  ·  ↵ connect  ·  esc close"
    model: filtered
    countText: statusText
    itemHeight: Theme.rowHeight
    maxVisible: 10
    panelHeight: 560

    onPanelOpened: {
        statusRaw = ""
        locationsRaw = ""
        statusProc.running = true
        locationsProc.running = true
    }
    onQueryChanged: applyFilter()
    onActivated: (item, index) => runAction(item)

    function maybeRebuild() {
        if (statusProc.running || locationsProc.running)
            return
        rebuild(statusRaw || "○ Disconnected", locationsRaw)
    }

    function rebuild(statusLine, locationsText) {
        const list = []
        list.push({
            kind: "status",
            label: statusLine || "○ Disconnected",
            action: "noop"
        })
        list.push({
            kind: "action",
            label: "Disconnect",
            action: "disconnect"
        })
        // Best always first among connect options
        list.push({
            kind: "action",
            label: "Best location",
            action: "best"
        })

        const rows = (locationsText || "").split("\n")
        for (let i = 0; i < rows.length; i++) {
            let line = rows[i].trim()
            if (!line)
                continue
            if (/already running|aborting|error:|spdlog|cli:/i.test(line))
                continue
            let key = line
            let label = line
            const pipe = line.indexOf("|")
            if (pipe < 0)
                continue
            key = line.slice(0, pipe).trim()
            label = line.slice(pipe + 1).trim() || key
            if (key === "best" || /^best location$/i.test(label))
                continue
            list.push({
                kind: "location",
                label: label,
                detail: key,
                action: "connect",
                target: key
            })
        }

        entries = list
        statusText = statusLine || "○ Disconnected"
        applyFilter()
    }

    function applyFilter() {
        const q = searchText.trim().toLowerCase()
        if (!q) {
            filtered = entries.slice()
        } else {
            filtered = entries.filter(e => {
                if (e.kind === "status")
                    return true
                const blob = [e.label, e.detail, e.target, e.action].filter(Boolean).join(" ").toLowerCase()
                return blob.includes(q)
            })
        }
        clampSelection()
    }

    function runAction(item) {
        if (!item || item.action === "noop")
            return
        close()
        if (item.action === "disconnect") {
            actionProc.exec(["bash", helper, "disconnect"])
            return
        }
        if (item.action === "best") {
            actionProc.exec(["bash", helper, "best"])
            return
        }
        if (item.action === "connect") {
            actionProc.exec(["bash", helper, "connect", item.target || item.label])
        }
    }

    Process {
        id: statusProc
        command: ["bash", root.helper, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.statusRaw = text.trim()
                root.maybeRebuild()
            }
        }
        onRunningChanged: if (!running) root.maybeRebuild()
    }

    Process {
        id: locationsProc
        command: ["bash", root.helper, "locations"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.locationsRaw = text
                root.maybeRebuild()
            }
        }
        onRunningChanged: if (!running) root.maybeRebuild()
    }

    Process { id: actionProc }

    rowDelegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view ? ListView.view.width : root.panelWidth - 28
        height: Theme.rowHeight
        radius: Theme.radiusSm
        color: {
            if (modelData.kind === "status")
                return Theme.surfaceVariant
            return index === root.selectedIndex ? Theme.rowSelected : Theme.row
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            Text {
                text: modelData.kind === "status" ? "VPN" : (modelData.kind === "action" ? ">" : "•")
                color: index === root.selectedIndex && modelData.kind !== "status" ? Theme.textOnAccent : Theme.secondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                font.bold: true
                Layout.preferredWidth: 28
            }

            Text {
                Layout.fillWidth: true
                text: modelData.label
                color: index === root.selectedIndex && modelData.kind !== "status" ? Theme.textOnAccent : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.bold: modelData.kind === "status" || modelData.kind === "action"
                elide: Text.ElideRight
            }

            Text {
                visible: !!(modelData.detail && modelData.kind === "location")
                text: modelData.detail || ""
                color: index === root.selectedIndex ? Theme.textOnAccent : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                opacity: 0.85
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: modelData.kind !== "status"
            hoverEnabled: true
            onEntered: root.selectedIndex = index
            onClicked: {
                root.selectedIndex = index
                root.activateSelected()
            }
        }
    }
}
