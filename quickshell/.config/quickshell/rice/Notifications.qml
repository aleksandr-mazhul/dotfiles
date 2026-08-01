pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: root

    property bool open: false
    property bool dnd: false
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
            OverlayHub.closeAll()
            Qt.callLater(() => panel.forceActiveFocus())
        }
    }

    visible: open
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
        color: Theme.background
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.borderSubtle
        focus: root.open
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close()
                event.accepted = true
            }
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
                            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, dndMouse.containsMouse ? 0.32 : 0.22)
                        return dndMouse.containsMouse ? Theme.rowHover : "transparent"
                    }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RiceIcon {
                        anchors.centerIn: parent
                        customSource: Qt.resolvedUrl(root.dnd ? "assets/notif-bell-off.svg" : "assets/notif-bell.svg")
                        tint: root.dnd ? Theme.primary : "#ffffff"
                        implicitSize: 16
                    }
                    MouseArea {
                        id: dndMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dnd = !root.dnd
                    }
                }

                // Clear all
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 8
                    color: clearMouse.containsMouse ? Theme.rowHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RiceIcon {
                        anchors.centerIn: parent
                        customSource: Qt.resolvedUrl("assets/notif-clear.svg")
                        tint: "#ffffff"
                        implicitSize: 16
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
                    color: closeMouse.containsMouse ? Theme.rowHover : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RiceIcon {
                        anchors.centerIn: parent
                        name: "window-close"
                        implicitSize: 14
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
                    required property var modelData
                    width: ListView.view.width
                    // Taller cards: padding + min body area
                    height: Math.max(88, col.implicitHeight + 28)
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.borderSubtle

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
                                color: cardClose.containsMouse ? Theme.rowHover : "transparent"
                                RiceIcon {
                                    anchors.centerIn: parent
                                    name: "window-close"
                                    implicitSize: 12
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

                Text {
                    anchors.centerIn: parent
                    visible: root.unread === 0
                    text: root.dnd ? "Muted — nothing will appear here" : "No notifications"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
