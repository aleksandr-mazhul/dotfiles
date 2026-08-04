import QtQuick
import QtQuick.Layouts

// Compact HH:MM stepper — chevrons + mouse wheel.
Item {
    id: root

    property int hour: 10
    property int minute: 0
    property string label: ""
    readonly property int minuteStep: 5

    function bumpHour(delta) {
        hour = (hour + delta + 24) % 24
    }

    function bumpMinute(delta) {
        let m = minute + delta * minuteStep
        if (m >= 60) {
            m = 0
            bumpHour(1)
        } else if (m < 0) {
            m = 60 - minuteStep
            bumpHour(-1)
        }
        minute = m
    }

    function setTime(h, m) {
        hour = Math.max(0, Math.min(23, h | 0))
        let mm = Math.round((m | 0) / minuteStep) * minuteStep
        if (mm >= 60)
            mm = 60 - minuteStep
        if (mm < 0)
            mm = 0
        minute = mm
    }

    implicitWidth: 148
    implicitHeight: col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Text {
            text: root.label
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: Theme.radiusMd
            color: Theme.glassSurface
            border.width: 1
            border.color: Theme.glassBorderSubtle

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                // Hours
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text {
                        text: "▴"
                        color: hourUpMouse.containsMouse ? Theme.primary : Theme.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        scale: hourUpMouse.containsMouse ? 1.2 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: hourUpMouse
                            anchors.fill: parent
                            anchors.margins: -10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bumpHour(1)
                        }
                    }

                    Text {
                        text: String(root.hour).padStart(2, "0")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Text {
                        text: "▾"
                        color: hourDownMouse.containsMouse ? Theme.primary : Theme.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        scale: hourDownMouse.containsMouse ? 1.2 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: hourDownMouse
                            anchors.fill: parent
                            anchors.margins: -10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bumpHour(-1)
                        }
                    }
                }

                Text {
                    text: ":"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Minutes
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Text {
                        text: "▴"
                        color: minUpMouse.containsMouse ? Theme.primary : Theme.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        scale: minUpMouse.containsMouse ? 1.2 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: minUpMouse
                            anchors.fill: parent
                            anchors.margins: -10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bumpMinute(1)
                        }
                    }

                    Text {
                        text: String(root.minute).padStart(2, "0")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Text {
                        text: "▾"
                        color: minDownMouse.containsMouse ? Theme.primary : Theme.textMuted
                        font.pixelSize: 12
                        Layout.alignment: Qt.AlignHCenter
                        scale: minDownMouse.containsMouse ? 1.2 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: Theme.hoverMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }
                        MouseArea {
                            id: minDownMouse
                            anchors.fill: parent
                            anchors.margins: -10
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bumpMinute(-1)
                        }
                    }
                }
            }

            WheelHandler {
                onWheel: event => {
                    // Prefer changing minutes with wheel over the whole control
                    root.bumpMinute(event.angleDelta.y > 0 ? 1 : -1)
                    event.accepted = true
                }
            }
        }
    }
}
