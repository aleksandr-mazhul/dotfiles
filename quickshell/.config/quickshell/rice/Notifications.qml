pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

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

    function toggle() { open = !open }
    function show() { open = true }
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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    Layout.fillWidth: true
                }

                // DND / mute
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 8
                    color: {
                        if (root.dnd)
                            return dndMouse.containsMouse ? Theme.glassTileActiveHover : Theme.glassTileActive
                        return dndMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }
                    RiceIcon {
                        anchors.centerIn: parent
                        customSource: Qt.resolvedUrl(root.dnd ? "assets/notif-bell-off.svg" : "assets/notif-bell.svg")
                        tint: root.dnd ? Theme.primary : Theme.text
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

                // Clear all
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 8
                    color: clearMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }
                    RiceIcon {
                        anchors.centerIn: parent
                        customSource: Qt.resolvedUrl("assets/notif-clear.svg")
                        tint: Theme.text
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

                // Close panel
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 8
                    color: closeMouse.containsMouse ? Theme.glassSurfaceHover : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }
                    RiceIcon {
                        anchors.centerIn: parent
                        customSource: Qt.resolvedUrl("assets/close.svg")
                        tint: closeMouse.containsMouse ? Theme.text : Theme.textMuted
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

            Text {
                visible: root.dnd
                text: "Do not disturb — new notifications are blocked"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 10
                model: notifServer.trackedNotifications

                delegate: Rectangle {
                    id: notifCard
                    required property var modelData
                    readonly property bool hovered: cardHover.containsMouse
                    width: ListView.view.width
                    // Taller cards: padding + min body area
                    height: Math.max(88, col.implicitHeight + 28)
                    radius: Theme.radiusMd
                    color: notifCard.hovered ? Theme.glassSurfaceHover : Theme.glassSurface
                    border.width: 1
                    border.color: Theme.glassBorderSubtle
                    Behavior on color {
                        ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                    }

                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }

                    ColumnLayout {
                        id: col
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: modelData.summary || modelData.appName || "Notification"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 6
                                color: cardClose.containsMouse ? Theme.glassSurfaceHover : "transparent"
                                Behavior on color {
                                    ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                                }
                                RiceIcon {
                                    anchors.centerIn: parent
                                    customSource: Qt.resolvedUrl("assets/close.svg")
                                    tint: cardClose.containsMouse ? Theme.text : Theme.textMuted
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
                        }

                        Text {
                            visible: !!(modelData.body && modelData.body.length)
                            text: modelData.body || ""
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            wrapMode: Text.Wrap
                            Layout.fillWidth: true
                            lineHeight: 1.25
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.unread === 0
                    spacing: 8

                    RiceIcon {
                        Layout.alignment: Qt.AlignHCenter
                        customSource: Qt.resolvedUrl(root.dnd ? "assets/notif-bell-off.svg" : "assets/notif-bell.svg")
                        tint: Theme.textMuted
                        implicitSize: 28
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.dnd ? "Muted — nothing will appear here" : "No notifications"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
