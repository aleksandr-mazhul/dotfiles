import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property bool clickable: false
    property alias content: contentHost.data
    signal activated()

    implicitHeight: Theme.barHeight
    implicitWidth: Math.max(Theme.barHeight, contentHost.implicitWidth + Theme.barIslandPadH * 2)

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.barIslandRadius
        border.width: 1
        border.color: Theme.borderSubtle
    }

    RowLayout {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: Theme.barIslandPadH
        anchors.rightMargin: Theme.barIslandPadH
        anchors.topMargin: Theme.barIslandPadV
        anchors.bottomMargin: Theme.barIslandPadV
        spacing: 8
    }

    // Separate top catcher so tray icons / IconImage never steal presses.
    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false
        acceptedButtons: Qt.LeftButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        z: 100

        onPressed: event => {
            root.activated()
            event.accepted = true
        }
    }
}
