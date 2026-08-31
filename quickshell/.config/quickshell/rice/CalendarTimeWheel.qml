import QtQuick
import QtQuick.Layouts
import "ds" as DS

// Compact HH:MM stepper — chevrons + mouse wheel.
Item {
    id: root

    property int hour: 10
    property int minute: 0
    property string label: ""
    readonly property int minuteStep: 5
    readonly property int wellRadius: DS.Tokens.innerRadius(DS.Tokens.radiusSurface, DS.Tokens.paddingSurface)

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

    component Chevron: Item {
        id: ch
        property string glyph: ""
        property bool hovered: mouse.containsMouse
        signal clicked()
        implicitWidth: lab.implicitWidth
        implicitHeight: lab.implicitHeight
        Layout.alignment: Qt.AlignHCenter

        DS.QuietText {
            id: lab
            anchors.centerIn: parent
            text: ch.glyph
            color: ch.hovered ? DS.Tokens.textPrimary : DS.Tokens.textTertiary
            font.family: DS.Tokens.fontUi
            font.pixelSize: DS.Tokens.fontSizeSm
            scale: ch.hovered ? 1.2 : 1.0
            Behavior on color {
                ColorAnimation { duration: DS.Tokens.stateMs; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ch.clicked()
        }
    }

    implicitWidth: 148
    implicitHeight: col.implicitHeight
    Layout.fillWidth: true

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        DS.QuietText {
            text: root.label
            color: DS.Tokens.textSecondary
            font.family: DS.Tokens.fontUi
            font.pixelSize: DS.Tokens.fontSizeSm
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: root.wellRadius
            color: DS.Tokens.fieldFill
            border.width: 1
            border.color: DS.Tokens.fieldRim

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 2

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Chevron {
                        glyph: "▴"
                        onClicked: root.bumpHour(1)
                    }

                    DS.QuietText {
                        text: String(root.hour).padStart(2, "0")
                        color: DS.Tokens.textPrimary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSize
                        fontBold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Chevron {
                        glyph: "▾"
                        onClicked: root.bumpHour(-1)
                    }
                }

                DS.QuietText {
                    text: ":"
                    color: DS.Tokens.textSecondary
                    font.family: DS.Tokens.fontUi
                    font.pixelSize: DS.Tokens.fontSize
                    fontBold: true
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Chevron {
                        glyph: "▴"
                        onClicked: root.bumpMinute(1)
                    }

                    DS.QuietText {
                        text: String(root.minute).padStart(2, "0")
                        color: DS.Tokens.textPrimary
                        font.family: DS.Tokens.fontUi
                        font.pixelSize: DS.Tokens.fontSize
                        fontBold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    Chevron {
                        glyph: "▾"
                        onClicked: root.bumpMinute(-1)
                    }
                }
            }

            WheelHandler {
                onWheel: event => {
                    root.bumpMinute(event.angleDelta.y > 0 ? 1 : -1)
                    event.accepted = true
                }
            }
        }
    }
}
