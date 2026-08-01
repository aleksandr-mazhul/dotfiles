pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool open: false

    function toggle() { open = !open }
    function show() { open = true }
    function close() { open = false }

    onOpenChanged: {
        if (open)
            OverlayHub.closeAll()
    }

    visible: open
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: 320
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rice-calendar"
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

                Text {
                    text: Qt.formatDate(new Date(), "MMMM yyyy")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLg
                    font.bold: true
                    Layout.fillWidth: true
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

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        required property string modelData
                        text: modelData
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: {
                        const now = new Date()
                        const year = now.getFullYear()
                        const month = now.getMonth()
                        const first = new Date(year, month, 1)
                        const start = (first.getDay() + 6) % 7
                        const daysInMonth = new Date(year, month + 1, 0).getDate()
                        const today = now.getDate()
                        const cells = []
                        for (let i = 0; i < start; i++)
                            cells.push({ day: 0, today: false })
                        for (let d = 1; d <= daysInMonth; d++)
                            cells.push({ day: d, today: d === today })
                        return cells
                    }

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.radiusSm
                        color: modelData.today ? Theme.primary : "transparent"
                        visible: modelData.day > 0

                        Text {
                            anchors.centerIn: parent
                            text: modelData.day > 0 ? String(modelData.day) : ""
                            color: modelData.today ? Theme.textOnAccent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.bold: modelData.today
                        }
                    }
                }
            }
        }
    }
}
