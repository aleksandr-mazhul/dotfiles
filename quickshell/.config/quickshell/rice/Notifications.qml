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
    readonly property int unread: notifServer.trackedNotifications.length

    readonly property var notifServer: NotificationServer {
        onNotification: notification => {
            notification.tracked = !root.dnd
        }
    }

    function toggle() { open = !open }
    function show() { open = true }
    function close() { open = false }

    function dismissAll() {
        const list = notifServer.trackedNotifications
        for (let i = list.length - 1; i >= 0; i--)
            list[i].dismiss()
    }

    onOpenChanged: {
        if (open)
            OverlayHub.closeAll()
    }

    visible: open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: Math.min(480, 88 + Math.max(1, notifServer.trackedNotifications.length) * 88)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + Theme.barMargin * 2 + 6
        right: Theme.barMargin
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.background
        radius: Theme.radiusLg
        border.width: 1
        border.color: Theme.borderSubtle

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: root.dnd ? "󰂛" : "󰂚"
                    color: root.dnd ? Theme.primary : Theme.textMuted
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dnd = !root.dnd
                    }
                }

                Text {
                    text: "󰂠"
                    color: Theme.textMuted
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissAll()
                    }
                }

                Text {
                    text: "󰅖"
                    color: Theme.textMuted
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
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
                    required property var modelData
                    width: ListView.view.width
                    height: col.implicitHeight + 16
                    radius: Theme.radiusMd
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.borderSubtle

                    ColumnLayout {
                        id: col
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: modelData.summary || modelData.appName || "Notification"
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "󰅖"
                                color: Theme.textMuted
                                font.pixelSize: 14
                                font.family: "JetBrainsMono Nerd Font, JetBrains Mono, sans-serif"
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
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
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: notifServer.trackedNotifications.length === 0
                    text: root.dnd ? "Do not disturb" : "No notifications"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
