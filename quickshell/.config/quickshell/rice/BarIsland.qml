import QtQuick
import QtQuick.Layouts

// Root is MouseArea so clicks always hit this island (not child IconImage/ColorOverlay).
MouseArea {
    id: root

    property bool clickable: false
    property alias content: contentHost.data
    signal activated()

    implicitHeight: Theme.barHeight
    implicitWidth: Math.max(Theme.barHeight, contentHost.implicitWidth + Theme.barIslandPadH * 2)

    // When not clickable, let children (e.g. workspace cells) receive clicks.
    acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
    hoverEnabled: true
    preventStealing: root.clickable
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor

    onClicked: {
        if (root.clickable)
            root.activated()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.barIslandRadius
        border.width: 1
        border.color: Theme.borderSubtle
        z: -1
    }

    RowLayout {
        id: contentHost
        // When this island is the button, disable children so IconImage /
        // ColorOverlay cannot steal the click from this MouseArea.
        enabled: !root.clickable
        anchors.fill: parent
        anchors.leftMargin: Theme.barIslandPadH
        anchors.rightMargin: Theme.barIslandPadH
        anchors.topMargin: Theme.barIslandPadV
        anchors.bottomMargin: Theme.barIslandPadV
        spacing: 8
    }
}
