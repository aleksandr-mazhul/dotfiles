pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "ds" as DS

PanelWindow {
    id: root

    property bool open: false
    // Bound to OverlayHub so mute survives reboot / qs reload.
    property bool dnd: OverlayHub.notifDnd
    property int unread: 0

    NotificationServer {
        id: notifServer
        onNotification: notification => {
            if (root.dnd) {
                // Mute: drop immediately, don't keep in the list.
                notification.tracked = false
                notification.dismiss()
                return
            }
            notification.tracked = true
        }
    }

    Binding {
        target: root
        property: "unread"
        value: {
            try {
                return notifServer.trackedNotifications.values.length
            } catch (e) {
                return 0
            }
        }
    }

    function sceneGeom(outsideBand) {
        const scr = root.screen
        const ox = scr ? Math.round(scr.x) : 0
        const oy = scr ? Math.round(scr.y) : 0
        const sw = scr ? Math.round(scr.width) : 0
        const w = Math.round(root.implicitWidth)
        let h = Math.round(root.implicitHeight)
        if (w < 32)
            return ""
        if (h < 32)
            h = 420
        let gx = ox + sw - root.margins.right - w
        let gy = oy + root.margins.top
        if (gx < 0)
            gx = 0
        if (gy < 0)
            gy = 0
        if (outsideBand) {
            const band = 28
            const by = Math.max(0, gy - band)
            return gx + "," + by + " " + w + "x" + band
        }
        return gx + "," + gy + " " + w + "x" + h
    }

    function refreshScene(outsideBand) {
        DS.AdaptiveContrast.refresh(root.sceneGeom(!!outsideBand))
    }

    function toggle() {
        if (open)
            close()
        else
            show()
    }
    function show() {
        root.refreshScene(false)
        open = true
    }
    function close() { open = false }

    function dismissAll() {
        const list = notifServer.trackedNotifications
        try {
            const vals = list.values
            for (let i = vals.length - 1; i >= 0; i--)
                vals[i].dismiss()
        } catch (e) {
            for (let i = list.length - 1; i >= 0; i--)
                list[i].dismiss()
        }
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop()
            OverlayHub.closeAll()
            openAnim.play()
            Qt.callLater(() => panel.forceActiveFocus())
        } else {
            openAnim.stop()
            closeAnim.play()
        }
    }

    // Stay visible through the close animation so it doesn't vanish mid-fade.
    visible: open || closeAnim.running
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    implicitWidth: 380
    implicitHeight: 420
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-notifications"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        right: true
    }

    margins {
        top: Theme.barHeight + Theme.barMargin * 2 + 6
        right: Theme.barMargin
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (root.open)
                root.refreshScene(true)
        }
    }

    Item {
        id: panel
        anchors.fill: parent
        focus: root.open
        transformOrigin: Item.TopRight
        opacity: 1
        scale: 1
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
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

        DS.GlassSurface {
            anchors.fill: parent
            radius: DS.Tokens.radiusSurface

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: DS.Tokens.paddingSurface
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: DS.Tokens.radiusMin
                        color: root.dnd
                            ? DS.Tokens.raisedStrong
                            : (dndMouse.containsMouse ? DS.Tokens.raised : "transparent")
                        border.width: root.dnd ? 1 : 0
                        border.color: DS.Tokens.raisedRim
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }

                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl(root.dnd ? "assets/notif-bell-off.svg" : "assets/notif-bell.svg")
                            tint: dndMouse.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                            implicitSize: 16
                            scale: dndMouse.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: OverlayHub.notifDnd = !OverlayHub.notifDnd
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: DS.Tokens.radiusMin
                        color: clearMouse.containsMouse ? DS.Tokens.raised : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }
                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/notif-clear.svg")
                            tint: clearMouse.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                            implicitSize: 16
                            scale: clearMouse.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.dismissAll()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: DS.Tokens.radiusMin
                        color: closeMouse.containsMouse ? DS.Tokens.raised : "transparent"
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }
                        RiceIcon {
                            anchors.centerIn: parent
                            customSource: Qt.resolvedUrl("assets/close.svg")
                            tint: closeMouse.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                            implicitSize: 14
                            scale: closeMouse.containsMouse ? 1.1 : 1.0
                            Behavior on scale {
                                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                            }
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: notifServer.trackedNotifications

                    delegate: Rectangle {
                        id: notifCard
                        required property var modelData
                        readonly property bool hovered: cardHover.containsMouse
                        width: ListView.view.width
                        height: Math.max(col.implicitHeight + 28, DS.Tokens.rowHeight)
                        radius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)
                        color: notifCard.hovered ? DS.Tokens.raised : "transparent"
                        border.width: notifCard.hovered ? 1 : 0
                        border.color: DS.Tokens.raisedRim
                        Behavior on color {
                            ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                        }

                        MouseArea {
                            id: cardHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }

                        Rectangle {
                            id: dismissBtn
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.rightMargin: 10
                            width: 24
                            height: 24
                            radius: DS.Tokens.radiusMin
                            color: cardClose.containsMouse ? DS.Tokens.raised : "transparent"
                            Behavior on color {
                                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
                            }
                            RiceIcon {
                                anchors.centerIn: parent
                                customSource: Qt.resolvedUrl("assets/close.svg")
                                tint: cardClose.containsMouse ? DS.Tokens.textPrimary : DS.Tokens.textIcon
                                implicitSize: 12
                                scale: cardClose.containsMouse ? 1.1 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                                }
                            }
                            MouseArea {
                                id: cardClose
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.dismiss()
                            }
                        }

                        ColumnLayout {
                            id: col
                            anchors.left: parent.left
                            anchors.right: dismissBtn.left
                            anchors.top: parent.top
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            anchors.topMargin: 14
                            spacing: 8

                            DS.QuietText {
                                text: modelData.summary || modelData.appName || "Notification"
                                color: DS.Tokens.textPrimary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSize
                                fontWeight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }

                            DS.QuietText {
                                visible: !!(modelData.body && modelData.body.length)
                                text: modelData.body || ""
                                color: DS.Tokens.textSecondary
                                font.family: DS.Tokens.fontUi
                                font.pixelSize: DS.Tokens.fontSizeSm
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }
                        }
                    }

                    DS.QuietText {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: root.unread === 0
                        text: root.dnd ? "Muted — nothing will appear here" : "No notifications"
                        color: DS.Tokens.textSecondary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSize
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
