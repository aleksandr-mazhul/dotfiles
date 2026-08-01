pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

PanelWindow {
    id: root

    property bool open: false
    property string expanded: ""
    property int updateCount: 0
    property string netStatus: "…"
    property string btStatus: "…"
    property string vpnStatus: "…"
    property var wifiList: []
    property var btList: []
    property var sinkList: []

    function toggle() { open = !open }
    function show() { open = true }
    function close() { open = false; expanded = "" }

    onOpenChanged: {
        if (open) {
            OverlayHub.closeAll()
            refreshStatus()
        } else {
            expanded = ""
        }
    }

    function refreshStatus() {
        netProc.running = true
        btProc.running = true
        vpnProc.running = true
        updatesProc.running = true
    }

    function setExpanded(id) {
        expanded = (expanded === id) ? "" : id
        if (expanded === "network")
            wifiProc.running = true
        if (expanded === "bluetooth")
            btListProc.running = true
        if (expanded === "soundOut" || expanded === "soundIn")
            sinkListProc.running = true
    }

    visible: open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.qsPanelWidth
    implicitHeight: panelCol.implicitHeight + 24
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-quicksettings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + Theme.barMargin * 2 + 6
        right: Theme.barMargin
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real sinkVol: sink && sink.audio ? sink.audio.volume : 0
    readonly property real sourceVol: source && source.audio ? source.audio.volume : 0
    readonly property bool sinkMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : false

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.borderSubtle

        ColumnLayout {
            id: panelCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true

                QSTile {
                    title: "Network"
                    subtitle: root.netStatus
                    iconText: "󰈀"
                    expanded: root.expanded === "network"
                    onClicked: root.setExpanded("network")
                }
                QSTile {
                    title: "Bluetooth"
                    subtitle: root.btStatus
                    iconText: "󰂯"
                    expanded: root.expanded === "bluetooth"
                    onClicked: root.setExpanded("bluetooth")
                }
                QSTile {
                    title: "VPN"
                    subtitle: root.vpnStatus
                    iconText: "󰌾"
                    showChevron: false
                    onClicked: {
                        root.close()
                        OverlayHub.open("vpn")
                    }
                }
                QSTile {
                    title: "Updates"
                    subtitle: root.updateCount > 0 ? (root.updateCount + " available") : "Up to date"
                    iconText: "󰚰"
                    showChevron: false
                    onClicked: {
                        root.close()
                        Quickshell.execDetached(["kitty", "-e", "bash", "-lc", "sudo pacman -Syu; echo; read -n1 -p 'Press any key…'"])
                    }
                }
                QSTile {
                    title: "Power"
                    subtitle: root.expanded === "power" ? "Hold to confirm" : "Hold to shut down"
                    iconText: "󰐥"
                    expanded: root.expanded === "power"
                    Layout.columnSpan: 2
                    onClicked: root.setExpanded("power")
                }
            }

            ExpandSection {
                visible: root.expanded === "network"
                Layout.fillWidth: true
                title: "Wi-Fi"
                model: root.wifiList
                onActivated: item => {
                    if (item && item.ssid)
                        Quickshell.execDetached(["nmcli", "device", "wifi", "connect", item.ssid])
                }
            }

            ExpandSection {
                visible: root.expanded === "bluetooth"
                Layout.fillWidth: true
                title: "Devices"
                model: root.btList
                buttonLabel: "Connect"
                onActivated: item => {
                    if (item && item.mac)
                        Quickshell.execDetached(["bluetoothctl", "connect", item.mac])
                }
            }

            ColumnLayout {
                visible: root.expanded === "power"
                Layout.fillWidth: true
                spacing: 6
                PowerRow { label: "Shut Down"; iconText: "󰐥"; onActivated: Quickshell.execDetached(["systemctl", "poweroff"]) }
                PowerRow { label: "Reboot"; iconText: "󰜉"; onActivated: Quickshell.execDetached(["systemctl", "reboot"]) }
                PowerRow { label: "Suspend"; iconText: "󰤄"; onActivated: Quickshell.execDetached(["systemctl", "suspend"]) }
                PowerRow { label: "Lock"; iconText: "󰌾"; onActivated: Quickshell.execDetached(["hyprlock"]) }
                PowerRow {
                    label: "Log Out"
                    iconText: "󰍃"
                    onActivated: Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                }
            }

            SoundRow {
                Layout.fillWidth: true
                iconText: root.sinkMuted ? "󰝟" : "󰕾"
                value: root.sinkMuted ? 0 : root.sinkVol
                expanded: root.expanded === "soundOut"
                onIconClicked: {
                    if (root.sink && root.sink.audio)
                        root.sink.audio.muted = !root.sink.audio.muted
                }
                onMoved: v => {
                    if (root.sink && root.sink.audio) {
                        root.sink.audio.muted = false
                        root.sink.audio.volume = v
                    }
                }
                onToggleExpand: root.setExpanded("soundOut")
            }

            ColumnLayout {
                visible: root.expanded === "soundOut"
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Sound"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Repeater {
                    model: root.sinkList
                    delegate: DeviceRow {
                        required property var modelData
                        label: modelData.label
                        checked: modelData.default
                        onActivated: {
                            if (modelData.name)
                                Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
                            sinkListProc.running = true
                        }
                    }
                }
            }

            SoundRow {
                Layout.fillWidth: true
                iconText: root.sourceMuted ? "󰍭" : "󰍬"
                value: root.sourceMuted ? 0 : root.sourceVol
                expanded: root.expanded === "soundIn"
                onIconClicked: {
                    if (root.source && root.source.audio)
                        root.source.audio.muted = !root.source.audio.muted
                }
                onMoved: v => {
                    if (root.source && root.source.audio) {
                        root.source.audio.muted = false
                        root.source.audio.volume = v
                    }
                }
                onToggleExpand: root.setExpanded("soundIn")
            }
        }
    }

    Process {
        id: netProc
        command: ["bash", "-lc", "nmcli -t -f TYPE,STATE,CONNECTION device | awk -F: '$2==\"connected\"{print $1\"|\"$3; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (!t) {
                    root.netStatus = "Disconnected"
                    return
                }
                const parts = t.split("|")
                root.netStatus = parts[0] === "ethernet" ? "Ethernet" : (parts[1] || "Connected")
            }
        }
    }
    Process {
        id: btProc
        command: ["bash", "-lc", "bluetoothctl show 2>/dev/null | awk -F': ' '/Powered/{print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: root.btStatus = (text.trim() === "yes") ? "Enabled" : "Disabled"
        }
    }
    Process {
        id: vpnProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-vpn.sh status 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.vpnStatus = text.trim() || "Disconnected"
        }
    }
    Process {
        id: updatesProc
        command: ["bash", "-lc", "checkupdates 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.updateCount = parseInt(text.trim() || "0", 10) || 0
        }
    }
    Process {
        id: wifiProc
        command: ["bash", "-lc", "nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null | head -12"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split(":")
                    const ssid = p[0]
                    if (!ssid)
                        return
                    rows.push({
                        label: ssid,
                        detail: (p[2] || "Open") + " · " + (p[1] || "?") + "%",
                        ssid: ssid
                    })
                })
                root.wifiList = rows
            }
        }
    }
    Process {
        id: btListProc
        command: ["bash", "-lc", "bluetoothctl devices 2>/dev/null | head -12"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.*)$/)
                    if (!m)
                        return
                    rows.push({ label: m[2], detail: m[1], mac: m[1] })
                })
                root.btList = rows
            }
        }
    }
    Process {
        id: sinkListProc
        command: ["bash", "-lc", "wpctl status 2>/dev/null | awk '/Sinks:/{p=1;next}/Sources:/{p=0} p && /[0-9]+\\./{gsub(/^[\\t *]+/,\"\"); print}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    const m = line.match(/^(\*?\s*)(\d+)\.\s+(.*)$/)
                    if (!m)
                        return
                    rows.push({
                        id: m[2],
                        label: m[3].replace(/\s*\[.*$/, ""),
                        default: m[1].indexOf("*") >= 0,
                        name: m[3]
                    })
                })
                root.sinkList = rows
            }
        }
    }

    component QSTile: Rectangle {
        id: tile
        property string title
        property string subtitle
        property string iconText
        property bool expanded: false
        property bool showChevron: true
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: Theme.radiusMd
        color: Theme.surface
        border.width: 1
        border.color: Theme.borderSubtle

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            Text {
                text: tile.iconText
                color: Theme.primary
                font.pixelSize: 18
                font.family: "JetBrainsMono Nerd Font, JetBrains Mono"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: tile.title
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    text: tile.subtitle
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
            Text {
                visible: tile.showChevron
                text: tile.expanded ? "󰅃" : "󰅀"
                color: Theme.textMuted
                font.pixelSize: 14
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }
    }

    component PowerRow: Rectangle {
        property string label
        property string iconText
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: Theme.radiusSm
        color: Theme.surface
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            Text { text: iconText; color: Theme.primary; font.pixelSize: 16 }
            Text {
                text: label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                Layout.fillWidth: true
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: activated()
        }
    }

    component SoundRow: RowLayout {
        property string iconText
        property real value
        property bool expanded: false
        signal iconClicked()
        signal moved(real v)
        signal toggleExpand()

        spacing: 8
        Text {
            text: iconText
            color: Theme.primary
            font.pixelSize: 18
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: iconClicked()
            }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 1
            value: parent.value
            onMoved: parent.moved(value)
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 8
                width: slider.availableWidth
                height: implicitHeight
                radius: 4
                color: Theme.surfaceVariant
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    color: Theme.primary
                    radius: 4
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 16
                height: 16
                radius: 8
                color: Theme.primary
            }
        }
        Text {
            text: expanded ? "󰅃" : "󰅀"
            color: Theme.textMuted
            font.pixelSize: 14
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleExpand()
            }
        }
    }

    component DeviceRow: Rectangle {
        property string label
        property bool checked: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Theme.radiusSm
        color: Theme.surface
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            Text {
                text: label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Rectangle {
                width: 16
                height: 16
                radius: 4
                border.color: Theme.primary
                border.width: 1
                color: "transparent"
                Text {
                    anchors.centerIn: parent
                    visible: checked
                    text: "✓"
                    color: Theme.primary
                    font.pixelSize: 11
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: activated()
        }
    }

    component ExpandSection: ColumnLayout {
        property string title
        property var model: []
        property string buttonLabel: "Connect"
        signal activated(var item)
        spacing: 6
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        Text {
            text: title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
        }
        Repeater {
            model: parent.model
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusSm
                color: Theme.surface
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: modelData.label || ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: !!(modelData.detail)
                            text: modelData.detail || ""
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Text {
                        text: buttonLabel
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activated(modelData)
                        }
                    }
                }
            }
        }
    }
}
