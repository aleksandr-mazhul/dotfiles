import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    property var quickSettings
    property var calendar
    property var notifCenter

    screen: modelData
    color: "transparent"
    implicitHeight: Theme.barHeight + Theme.barMargin * 2

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: Theme.barMargin
        left: Theme.barMargin
        right: Theme.barMargin
    }

    exclusiveZone: Theme.barHeight + Theme.barMargin
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"

    RowLayout {
        anchors.fill: parent
        spacing: Theme.barGap

        RowLayout {
            spacing: Theme.barGap
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

            BarWorkspaces {}
            BarActiveWindow {}
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: Theme.barGap
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

            BarTray {}

            BarQsButton {
                active: !!(quickSettings && quickSettings.open)
                onClicked: {
                    if (calendar)
                        calendar.open = false
                    if (notifCenter)
                        notifCenter.open = false
                    if (quickSettings)
                        quickSettings.toggle()
                }
            }

            BarClockButton {
                onClicked: {
                    if (quickSettings)
                        quickSettings.open = false
                    if (notifCenter)
                        notifCenter.open = false
                    if (calendar)
                        calendar.toggle()
                }
            }

            BarNotifButton {
                muted: !!(notifCenter && notifCenter.dnd)
                unread: notifCenter ? notifCenter.unread : 0
                onClicked: {
                    if (quickSettings)
                        quickSettings.open = false
                    if (calendar)
                        calendar.open = false
                    if (notifCenter)
                        notifCenter.toggle()
                }
            }
        }
    }
}
