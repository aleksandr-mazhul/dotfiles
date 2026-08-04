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
    property int updatePacCount: 0
    property int updateAurCount: 0
    property string netStatus: "…"
    property string btStatus: "…"
    property string vpnStatus: "…"
    property bool vpnConnected: false
    property bool vpnBusy: false
    property bool btScanning: false
    property bool vpnLoading: false
    property bool updatesLoading: false
    property var wifiList: []
    property var btList: []
    property var vpnList: []
    property var updateList: []
    property var sinkList: []
    property var sourceList: []
    property real brightness: 0.7
    property var brightMonitors: []
    property string brightTarget: "all"
    // True while any QS slider is being dragged — keeps panel open / blocks flick steal.
    property bool sliderGrabbed: false

    function toggle() { open = !open }
    function show() { open = true }
    function close() { open = false }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            OverlayHub.closeAll()
            refreshStatus()
            openAnim.play()
            Qt.callLater(() => panel.forceActiveFocus())
        } else {
            openAnim.stop()
            closeAnim.play()
            expanded = ""
        }
    }

    function refreshStatus() {
        netProc.running = true
        btProc.running = true
        vpnProc.running = true
        updatesProc.running = true
        brightGetProc.running = true
        brightListProc.running = true
    }

    function setBrightness(v) {
        const pct = Math.round(Math.max(0, Math.min(1, v)) * 100)
        root.brightness = pct / 100
        brightSetProc.command = ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh set " + pct]
        brightSetProc.running = true
    }

    function setBrightTarget(id) {
        root.brightTarget = String(id)
        brightTargetProc.command = [
            "bash", "-lc",
            "~/.config/hypr/scripts/qs-brightness.sh target " + String(id)
        ]
        brightTargetProc.running = true
        // Refresh slider value for the selected scope.
        Qt.callLater(() => { brightGetProc.running = true })
        Qt.callLater(() => { brightListProc.running = true })
    }

    function setExpanded(id) {
        expanded = (expanded === id) ? "" : id
        if (expanded === "network")
            wifiProc.running = true
        if (expanded === "bluetooth") {
            root.btScanning = true
            root.btList = []
            btListProc.running = true
        }
        if (expanded === "vpn") {
            root.vpnLoading = true
            root.vpnList = []
            vpnListProc.running = true
            vpnProc.running = true
        }
        if (expanded === "updates") {
            root.updatesLoading = true
            root.updateList = []
            updatesProc.running = true
            updatesListProc.running = true
        }
        if (expanded === "soundOut")
            sinkListProc.running = true
        if (expanded === "soundIn")
            sourceListProc.running = true
        if (expanded === "brightness")
            brightListProc.running = true
    }

    function runNetworkQuick() {
        // Join the strongest Wi‑Fi (ethernet stays as-is).
        Quickshell.execDetached([
            "bash", "-lc",
            "nmcli radio wifi on; " +
            "ssid=$(nmcli -t -f SSID,SIGNAL,IN-USE device wifi list 2>/dev/null | awk -F: '$1!=\"\" && $3!=\"*\"{print $2\"\\t\"$1}' | sort -nr | head -1 | cut -f2-); " +
            "if [ -n \"$ssid\" ]; then nmcli device wifi connect \"$ssid\"; fi; " +
            "true"
        ])
        netProc.running = true
        Qt.callLater(() => { wifiProc.running = true })
    }

    function runBluetoothQuick() {
        const enable = root.btStatus !== "Enabled"
        Quickshell.execDetached([
            "bash", "-lc",
            enable ? "bluetoothctl power on" : "bluetoothctl power off"
        ])
        root.btStatus = enable ? "Enabled" : "Disabled"
        Qt.callLater(() => { btProc.running = true })
    }

    function runVpnQuick() {
        if (root.vpnConnected)
            root.runVpn("disconnect")
        else
            root.runVpn("best")
    }

    function runVpn(action, loc) {
        if (root.vpnBusy)
            return
        root.vpnBusy = true
        if (action === "disconnect") {
            root.vpnStatus = "○ Disconnecting…"
            root.vpnConnected = false
            Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/qs-vpn.sh disconnect"])
        } else if (action === "best" || loc === "best") {
            root.vpnStatus = "● Connecting…"
            root.vpnConnected = true
            Quickshell.execDetached(["bash", "-lc", "~/.config/hypr/scripts/qs-vpn.sh best"])
        } else {
            root.vpnStatus = "● Connecting…"
            root.vpnConnected = true
            const safe = String(loc || "").replace(/'/g, "")
            Quickshell.execDetached([
                "bash", "-lc",
                "~/.config/hypr/scripts/qs-vpn.sh connect '" + safe + "'"
            ])
        }
        vpnRefresh.restart()
        vpnSettle.restart()
    }

    function runUpdate(kind) {
        // Keep panel open; launch a terminal so sudo/yay can ask for input.
        const ask = "export SUDO_ASKPASS=\"$HOME/.local/bin/sudo-askpass-gtk.py\"; "
        let cmd = ""
        if (kind === "pac")
            cmd = ask + "sudo -A pacman -Syu; echo; read -n1 -rsp 'Done — press any key…'"
        else if (kind === "aur")
            cmd = "yay -Syu; echo; read -n1 -rsp 'Done — press any key…'"
        else if (kind === "all")
            cmd = ask + "sudo -A pacman -Syu && yay -Syu; echo; read -n1 -rsp 'Done — press any key…'"
        else if (kind === "check") {
            root.updatesLoading = true
            updatesProc.running = true
            updatesListProc.running = true
            return
        }
        if (!cmd)
            return
        Quickshell.execDetached(["kitty", "--title", "Updates", "-e", "bash", "-lc", cmd])
    }

    // Stay visible through the close animation so it doesn't vanish mid-fade.
    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    // Compact window — fixed size so open/expand never resizes the layer (jerky on 165Hz).
    implicitWidth: Theme.qsPanelWidth
    implicitHeight: Theme.qsPanelHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-quicksettings"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    // Pinned bar already reserves its strip — only leave qsPanelGap under it.
    // Unpinned: clear the floating bar height so the title isn't covered.
    margins {
        top: OverlayHub.barPinned
            ? Theme.qsPanelGap
            : (Theme.barHeight + Theme.barMargin * 2 + Theme.qsPanelGap)
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
    readonly property string sinkBlob: {
        if (!sink)
            return ""
        return [sink.name, sink.nickname, sink.description].filter(Boolean).join(" ").toLowerCase()
    }
    readonly property bool sinkIsHeadphones: {
        if (!sink)
            return false
        const blob = sinkBlob
        // Don't treat the Logitech USB dongle (JBL Flip) as headphones
        if (/jbl|flip\s*\d|logitech.*usb.?headset|usb headset/.test(blob))
            return false
        return /headphone|earphone|earbuds|airpods|(^|[^a-z])headset([^a-z]|$)/.test(blob)
    }
    readonly property string sinkOutIcon: {
        if (sinkMuted)
            return sinkIsHeadphones ? "audio-headphones" : "audio-volume-muted"
        if (sinkIsHeadphones)
            return "audio-headphones"
        if (sinkVol < 0.34)
            return "audio-volume-low"
        if (sinkVol < 0.67)
            return "audio-volume-medium"
        return "audio-volume-high"
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Theme.glassBackground
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.glassBorder
        focus: root.open
        transformOrigin: Item.TopRight
        opacity: 1
        scale: 1
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (root.sliderGrabbed) {
                    event.accepted = true
                    return
                }
                root.close()
                event.accepted = true
            }
        }

        // Soft inner highlight — Apple-like glass edge without heavy chrome
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusLg - 1
            color: "transparent"
            border.width: 1
            border.color: Theme.glassBorderSubtle
        }

        RiceOpenAnim {
            id: openAnim
            target: panel
            fromScale: 0.96
        }

        RiceCloseAnim {
            id: closeAnim
            target: panel
            toScale: 0.96
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            z: 1
            contentWidth: width
            contentHeight: panelCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: panelCol
                width: flick.width
                spacing: 8

            GridLayout {
                columns: 2
                columnSpacing: 6
                rowSpacing: 6
                Layout.fillWidth: true

                RowLayout {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    Text {
                        text: "Quick Settings"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }
                    RiceIcon {
                        id: closeIcon
                        customSource: Qt.resolvedUrl("assets/close.svg")
                        tint: closeMouse.containsMouse ? Theme.text : Theme.textMuted
                        implicitSize: 14
                        Layout.preferredWidth: 14
                        Layout.preferredHeight: 14
                        scale: closeMouse.containsMouse ? 1.12 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                QSTile {
                    title: "Network"
                    subtitle: root.netStatus
                    iconName: "network-wired"
                    active: root.netStatus !== "…" && root.netStatus !== "Disconnected"
                    expanded: root.expanded === "network"
                    splitActions: true
                    onActivated: root.runNetworkQuick()
                    onExpandClicked: root.setExpanded("network")
                }
                QSTile {
                    title: "Bluetooth"
                    subtitle: root.btScanning && root.expanded === "bluetooth"
                        ? "Scanning…"
                        : root.btStatus
                    iconName: "bluetooth"
                    active: root.btStatus === "Enabled"
                    expanded: root.expanded === "bluetooth"
                    splitActions: true
                    onActivated: root.runBluetoothQuick()
                    onExpandClicked: root.setExpanded("bluetooth")
                }
                QSTile {
                    title: "VPN"
                    subtitle: root.vpnBusy
                        ? (root.vpnConnected ? "Disconnecting…" : "Connecting…")
                        : (root.vpnLoading && root.expanded === "vpn" ? "Loading regions…" : root.vpnStatus)
                    iconName: "network-vpn"
                    active: root.vpnConnected || root.vpnBusy
                    expanded: root.expanded === "vpn"
                    splitActions: true
                    onActivated: root.runVpnQuick()
                    onExpandClicked: root.setExpanded("vpn")
                }
                QSTile {
                    title: "Updates"
                    subtitle: root.updatesLoading && root.expanded === "updates"
                        ? "Checking…"
                        : (root.updateCount > 0
                            ? (root.updateCount + " available")
                            : "Up to date")
                    iconName: "view-refresh"
                    active: root.updateCount > 0
                    expanded: root.expanded === "updates"
                    onActivated: root.setExpanded("updates")
                    onExpandClicked: root.setExpanded("updates")
                }
                QSTile {
                    title: "Power"
                    subtitle: root.expanded === "power" ? "Choose action" : "Shut down / lock / sleep…"
                    iconName: "system-shutdown"
                    expanded: root.expanded === "power"
                    Layout.columnSpan: 2
                    onActivated: root.setExpanded("power")
                    onExpandClicked: root.setExpanded("power")
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
                visible: root.expanded === "bluetooth" && root.btList.length > 0
                Layout.fillWidth: true
                title: "Devices"
                model: root.btList
                buttonLabel: "Connect"
                onActivated: item => {
                    if (item && item.mac)
                        Quickshell.execDetached([
                            "bash", "-lc",
                            "bluetoothctl pair '" + item.mac + "' 2>/dev/null; bluetoothctl connect '" + item.mac + "'"
                        ])
                }
            }

            ColumnLayout {
                visible: root.expanded === "bluetooth" && root.btList.length === 0
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: root.btScanning ? "Scanning for devices…" : "No devices found nearby"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                PowerRow {
                    label: root.btScanning ? "Scanning…" : "Scan again"
                    iconName: "view-refresh"
                    onActivated: {
                        if (root.btScanning)
                            return
                        root.btScanning = true
                        root.btList = []
                        btListProc.running = true
                    }
                }
                PowerRow {
                    label: "Open Bluetooth settings"
                    iconName: "bluetooth"
                    onActivated: {
                        root.close()
                        Quickshell.execDetached(["bash", "-lc", "command -v blueman-manager >/dev/null && blueman-manager || gnome-control-center bluetooth || true"])
                    }
                }
            }

            ColumnLayout {
                visible: root.expanded === "vpn"
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: "Icon toggles Best / Disconnect · arrow opens list"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
                PowerRow {
                    label: "Search regions…"
                    detail: "Raycast picker with type-to-filter"
                    iconName: "edit-find"
                    fallbackIcon: "system-search"
                    onActivated: {
                        root.close()
                        Qt.callLater(() => OverlayHub.open("vpn"))
                    }
                }
                Text {
                    text: root.vpnLoading ? "Loading regions…" : "Regions"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    visible: !root.vpnLoading && root.vpnList.length === 0
                    text: "No regions available"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                ListView {
                    visible: root.vpnList.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(220, root.vpnList.length * 40)
                    clip: true
                    spacing: 4
                    model: root.vpnList
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 36
                        radius: Theme.radiusSm
                        color: vpnRow.containsMouse ? Theme.glassSurfaceHover : Theme.glassSurface
                        border.width: 1
                        border.color: Theme.glassBorderSubtle
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 10
                            text: modelData.label || modelData.key || ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: vpnRow
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runVpn("connect", modelData.key)
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.expanded === "updates"
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: root.updatePacCount + " system · " + root.updateAurCount + " AUR"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                PowerRow {
                    label: "Update all"
                    detail: "pacman + yay in a terminal"
                    iconName: "view-refresh"
                    onActivated: root.runUpdate("all")
                }
                PowerRow {
                    label: root.updatesLoading ? "Checking…" : "Refresh list"
                    detail: "Re-check pending packages"
                    iconName: "view-refresh"
                    onActivated: root.runUpdate("check")
                }
                Text {
                    visible: root.updateList.length > 0
                    text: "Pending packages"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    visible: !root.updatesLoading && root.updateList.length === 0
                    text: "Nothing to update"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                ListView {
                    visible: root.updateList.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(160, root.updateList.length * 36)
                    clip: true
                    spacing: 4
                    model: root.updateList
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 34
                        radius: Theme.radiusSm
                        color: Theme.glassSurface
                        border.width: 1
                        border.color: Theme.glassBorderSubtle
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Text {
                                text: modelData.kind === "aur" ? "AUR" : "SYS"
                                color: Theme.primary
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                font.bold: true
                                Layout.preferredWidth: 28
                            }
                            Text {
                                text: modelData.label || ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.detail || ""
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                elide: Text.ElideLeft
                                Layout.preferredWidth: 110
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.expanded === "power"
                Layout.fillWidth: true
                spacing: 6
                PowerRow {
                    label: "Shut Down"
                    detail: "Power off the PC"
                    iconName: "system-shutdown"
                    onActivated: Quickshell.execDetached(["systemctl", "poweroff"])
                }
                PowerRow {
                    label: "Reboot"
                    detail: "Restart the system"
                    iconName: "system-reboot"
                    onActivated: Quickshell.execDetached(["systemctl", "reboot"])
                }
                PowerRow {
                    label: "Suspend"
                    detail: "Sleep — keep apps in RAM"
                    iconName: "system-suspend"
                    onActivated: Quickshell.execDetached(["systemctl", "suspend"])
                }
                PowerRow {
                    label: "Lock"
                    detail: "Lock screen (hyprlock)"
                    iconName: "system-lock-screen"
                    onActivated: Quickshell.execDetached(["hyprlock"])
                }
                PowerRow {
                    label: "Log Out"
                    detail: "End Hyprland session"
                    iconName: "system-log-out"
                    onActivated: Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                }
            }

            SoundRow {
                Layout.fillWidth: true
                iconName: ""
                fallbackIcon: "weather-clear"
                customIconSource: Qt.resolvedUrl("assets/brightness-sun.svg")
                value: root.brightness
                expanded: root.expanded === "brightness"
                onIconClicked: root.setBrightness(0.65)
                onMoved: v => {
                    root.brightness = v
                    brightDebounce.restart()
                }
                onDragEnded: v => {
                    brightDebounce.stop()
                    root.setBrightness(v)
                }
                onToggleExpand: root.setExpanded("brightness")
            }

            ColumnLayout {
                visible: root.expanded === "brightness"
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Monitor"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    visible: root.brightMonitors.length < 2
                    text: "No extra monitors detected"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Repeater {
                    model: root.brightMonitors
                    delegate: DeviceRow {
                        required property var modelData
                        label: modelData.label
                        checked: modelData.selected
                        onActivated: root.setBrightTarget(modelData.id)
                    }
                }
            }

            SoundRow {
                Layout.fillWidth: true
                iconName: root.sinkOutIcon
                fallbackIcon: "audio-volume-high"
                struck: root.sinkMuted && root.sinkIsHeadphones
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
                    text: "Output"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    visible: root.sinkList.length === 0
                    text: "No output devices"
                    color: Theme.textMuted
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
                            Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
                            sinkListProc.running = true
                        }
                    }
                }
            }

            SoundRow {
                Layout.fillWidth: true
                iconName: root.sourceMuted ? "audio-input-microphone-muted" : "audio-input-microphone-high"
                fallbackIcon: "audio-input-microphone"
                struck: root.sourceMuted
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

            ColumnLayout {
                visible: root.expanded === "soundIn"
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Input"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Text {
                    visible: root.sourceList.length === 0
                    text: "No input devices"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                }
                Repeater {
                    model: root.sourceList
                    delegate: DeviceRow {
                        required property var modelData
                        label: modelData.label
                        checked: modelData.default
                        onActivated: {
                            Quickshell.execDetached(["wpctl", "set-default", String(modelData.id)])
                            sourceListProc.running = true
                        }
                    }
                }
            }
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
            onStreamFinished: {
                const t = text.trim() || "○ Disconnected"
                root.vpnStatus = t
                root.vpnConnected = t.indexOf("Connected") >= 0
            }
        }
    }
    Timer {
        id: vpnRefresh
        interval: 1200
        repeat: true
        onTriggered: {
            vpnProc.running = true
            if (!root.vpnBusy)
                stop()
        }
    }
    Timer {
        id: vpnSettle
        interval: 8000
        onTriggered: {
            root.vpnBusy = false
            vpnRefresh.stop()
            vpnProc.running = true
        }
    }
    Process {
        id: updatesProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-updates.sh count"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                root.updateCount = parseInt(lines[0] || "0", 10) || 0
                let pac = 0, aur = 0
                for (let i = 1; i < lines.length; i++) {
                    if (lines[i].indexOf("pac=") === 0)
                        pac = parseInt(lines[i].slice(4), 10) || 0
                    if (lines[i].indexOf("aur=") === 0)
                        aur = parseInt(lines[i].slice(4), 10) || 0
                }
                root.updatePacCount = pac
                root.updateAurCount = aur
            }
        }
    }
    Process {
        id: updatesListProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-updates.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split("|")
                    if (p.length < 2)
                        return
                    rows.push({
                        kind: p[0],
                        label: p[1],
                        detail: p[2] || ""
                    })
                })
                root.updateList = rows
                root.updatesLoading = false
            }
        }
    }
    Process {
        id: vpnListProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-vpn.sh locations"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    // Only accept "City|Label" rows — drop CLI chatter like
                    // "Windscribe CLI is already running"
                    const p = line.split("|")
                    if (p.length < 2 || !p[0] || !p[1])
                        return
                    const key = p[0].trim()
                    const label = p[1].trim()
                    if (!key || key === "best")
                        return
                    if (/already running|aborting|error/i.test(key + " " + label))
                        return
                    rows.push({ key: key, label: label })
                })
                root.vpnList = rows
                root.vpnLoading = false
            }
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
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-bt-devices.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split("|")
                    if (p.length < 2)
                        return
                    const paired = p[2] === "1"
                    const connected = p[3] === "1"
                    let detail = p[0]
                    if (connected)
                        detail = "Connected · " + detail
                    else if (paired)
                        detail = "Paired · " + detail
                    else
                        detail = "Nearby · " + detail
                    rows.push({
                        label: p[1],
                        detail: detail,
                        mac: p[0],
                        paired: paired,
                        connected: connected
                    })
                })
                // Named devices first, then MAC-only; connected/paired float up
                rows.sort((a, b) => {
                    const score = d => (d.connected ? 4 : 0) + (d.paired ? 2 : 0) + (d.label.indexOf("-") >= 0 && d.label === d.mac.replace(/:/g, "-") ? 0 : 1)
                    return score(b) - score(a)
                })
                root.btList = rows
                root.btScanning = false
            }
        }
    }
    Process {
        id: brightGetProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim(), 10)
                if (!isNaN(n) && !root.sliderGrabbed)
                    root.brightness = Math.max(0, Math.min(100, n)) / 100
            }
        }
    }
    Process {
        id: brightSetProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh get"]
    }
    Process {
        id: brightTargetProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh target all"]
    }
    Process {
        id: brightListProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-brightness.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                let target = "all"
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split("|")
                    if (p.length < 3)
                        return
                    const id = p[0]
                    const selected = p[2] === "1"
                    if (selected)
                        target = id
                    rows.push({
                        id: id,
                        label: p[1],
                        selected: selected
                    })
                })
                root.brightMonitors = rows
                root.brightTarget = target
            }
        }
    }
    Timer {
        id: brightDebounce
        interval: 120
        onTriggered: {
            if (!root.sliderGrabbed)
                root.setBrightness(root.brightness)
        }
    }

    Process {
        id: sinkListProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-audio-devices.sh sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split("|")
                    if (p.length < 3)
                        return
                    let label = p[1]
                    // Logitech USB dongle → the JBL Flip on this machine
                    if (/usb headset/i.test(label) || /logitech_logitech_usb_headset/i.test(label))
                        label = "JBL Flip 4"
                    rows.push({
                        id: p[0],
                        label: label,
                        default: p[2] === "1",
                        name: p[1]
                    })
                })
                root.sinkList = rows
            }
        }
    }
    Process {
        id: sourceListProc
        command: ["bash", "-lc", "~/.config/hypr/scripts/qs-audio-devices.sh sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                text.trim().split("\n").forEach(line => {
                    if (!line)
                        return
                    const p = line.split("|")
                    if (p.length < 3)
                        return
                    rows.push({
                        id: p[0],
                        label: p[1],
                        default: p[2] === "1",
                        name: p[1]
                    })
                })
                root.sourceList = rows
            }
        }
    }

    component QSTile: Rectangle {
        id: tile
        property string title
        property string subtitle
        property string iconName
        property string fallbackIcon: "dialog-information"
        property bool expanded: false
        property bool active: false
        property bool showChevron: true
        // Icon/body = quick action; chevron = expand. If false, whole tile expands.
        property bool splitActions: false
        property bool hovered: bodyMouse.containsMouse || chevMouse.containsMouse
        signal activated()
        signal expandClicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 54
        radius: Theme.radiusMd
        color: {
            if (tile.active)
                return tile.hovered ? Theme.glassTileActiveHover : Theme.glassTileActive
            return tile.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
        }
        border.width: 1
        border.color: tile.active
            ? Theme.glassTileBorder
            : Theme.glassBorderSubtle
        Behavior on color {
            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // Main hit target: icon + text
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                RowLayout {
                    anchors.fill: parent
                    spacing: 10
                    RiceIcon {
                        name: tile.iconName
                        fallback: tile.fallbackIcon
                        implicitSize: 18
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
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
                            color: tile.active ? Theme.primary : Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
                MouseArea {
                    id: bodyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tile.splitActions)
                            tile.activated()
                        else
                            tile.expandClicked()
                    }
                }
            }

            // Chevron only expands
            Rectangle {
                visible: tile.showChevron
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 8
                color: chevMouse.containsMouse ? Theme.rowHover : "transparent"
                Behavior on color {
                    ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                }
                RiceIcon {
                    anchors.centerIn: parent
                    name: tile.expanded ? "go-up" : "go-down"
                    implicitSize: 14
                    rotation: tile.expanded ? 180 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }
                }
                MouseArea {
                    id: chevMouse
                    anchors.fill: parent
                    enabled: tile.showChevron
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.expandClicked()
                }
            }
        }
    }

    component PowerRow: Rectangle {
        id: prow
        property string label
        property string detail: ""
        property string iconName
        property string fallbackIcon: "system-shutdown"
        property bool hovered: mouse.containsMouse
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: prow.detail.length ? 46 : 40
        radius: Theme.radiusSm
        color: prow.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
        border.width: 1
        border.color: Theme.glassBorderSubtle
        Behavior on color {
            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            RiceIcon {
                name: iconName
                fallback: fallbackIcon
                implicitSize: 16
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: label
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    Layout.fillWidth: true
                }
                Text {
                    visible: prow.detail.length > 0
                    text: prow.detail
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            z: 10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: activated()
        }
    }

    component SoundRow: RowLayout {
        id: srow
        property string iconName
        property string fallbackIcon: "audio-volume-high"
        property url customIconSource: ""
        property bool struck: false
        property real value
        property bool expanded: false
        property bool expandable: true
        signal iconClicked()
        signal moved(real v)
        signal dragEnded(real v)
        signal toggleExpand()

        spacing: 8
        Rectangle {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            color: iconMouse.containsMouse ? Theme.rowHover : "transparent"
            RiceIcon {
                anchors.centerIn: parent
                name: srow.iconName
                fallback: srow.fallbackIcon
                customSource: srow.customIconSource
                struck: srow.struck
                implicitSize: 18
            }
            MouseArea {
                id: iconMouse
                anchors.fill: parent
                z: 10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: srow.iconClicked()
            }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            // Tall hit-strip so you can grab/drag anywhere on the row, not only the 8px track.
            Layout.preferredHeight: 32
            from: 0
            to: 1
            live: true
            wheelEnabled: true
            topPadding: 12
            bottomPadding: 12
            leftPadding: 0
            rightPadding: 0

            // Don't fight the binding while the user is dragging.
            Binding {
                target: slider
                property: "value"
                value: srow.value
                when: !slider.pressed
                restoreMode: Binding.RestoreBindingOrValue
            }

            onPressedChanged: {
                // Flickable steals vertical/diagonal drags otherwise — menu feels "stuck"
                // and the panel can lose the gesture / close on release outside.
                flick.interactive = !pressed
                root.sliderGrabbed = pressed
                if (!pressed)
                    srow.dragEnded(slider.value)
            }
            onMoved: srow.moved(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 8
                width: slider.availableWidth
                height: implicitHeight
                radius: 4
                color: Theme.glassTrack
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    color: Theme.glassFill
                    radius: 4
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 18
                height: 18
                radius: 9
                color: Theme.primary
                border.width: 1
                border.color: Theme.glassBorder
                scale: slider.hovered || slider.pressed ? 1.10 : 1
                Behavior on scale {
                    NumberAnimation { duration: 80 }
                }
            }
        }
        Rectangle {
            visible: srow.expandable
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: 8
            color: chevMouse.containsMouse ? Theme.rowHover : "transparent"
            Behavior on color {
                ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
            }
            RiceIcon {
                anchors.centerIn: parent
                name: "go-down"
                implicitSize: 14
                rotation: srow.expanded ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                }
            }
            MouseArea {
                id: chevMouse
                anchors.fill: parent
                z: 10
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: srow.toggleExpand()
            }
        }
    }

    component DeviceRow: Rectangle {
        id: drow
        property string label
        property bool checked: false
        property bool hovered: mouse.containsMouse
        signal activated()
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Theme.radiusSm
        color: drow.checked
            ? (drow.hovered ? Theme.glassTileActiveHover : Theme.glassTileActive)
            : (drow.hovered ? Theme.glassSurfaceHover : Theme.glassSurface)
        border.width: 1
        border.color: drow.checked ? Theme.glassTileBorder : Theme.glassBorderSubtle
        Behavior on color {
            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
        }
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
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: activated()
        }
    }

    component ExpandSection: ColumnLayout {
        id: section
        property string title
        property var model: []
        property string buttonLabel: "Connect"
        signal activated(var item)
        spacing: 6

        Text {
            text: title
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
        }
        Repeater {
            model: section.model
            delegate: Rectangle {
                id: row
                required property var modelData
                property bool hovered: rowMouse.containsMouse
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusSm
                color: {
                    if (modelData.connected)
                        return row.hovered ? Theme.glassTileActiveHover : Theme.glassTileActive
                    return row.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                }
                border.width: 1
                border.color: modelData.connected
                    ? Theme.glassTileBorder
                    : Theme.glassBorderSubtle
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
                        text: modelData.connected ? "Connected" : section.buttonLabel
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.activated(modelData)
                }
            }
        }
    }
}
