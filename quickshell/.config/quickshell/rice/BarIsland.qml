import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    property alias content: contentHost.data
    property bool clickable: false
    signal clicked()

    color: Theme.surface
    radius: Theme.barIslandRadius
    implicitHeight: Theme.barHeight
    implicitWidth: contentHost.implicitWidth + Theme.barIslandPadH * 2
    border.width: 1
    border.color: Theme.borderSubtle

    default property alias children: contentHost.data

    RowLayout {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: Theme.barIslandPadH
        anchors.rightMargin: Theme.barIslandPadH
        anchors.topMargin: Theme.barIslandPadV
        anchors.bottomMargin: Theme.barIslandPadV
        spacing: 8
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.clickable
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
