import QtQuick
import QtQuick.Layouts

// Island chrome + hit target. TapHandler (not MouseArea) so the bar's
// HoverHandler cannot steal presses — same open/close hitbox every time.
Item {
    id: root

    property bool clickable: false
    property alias content: contentHost.data
    signal activated()

    implicitHeight: Theme.barHeight
    implicitWidth: Math.max(Theme.barHeight, contentHost.implicitWidth + Theme.barIslandPadH * 2)

    // Full-island hover + click target (matches the visible rounded rect).
    TapHandler {
        enabled: root.clickable
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.activated()
    }

    HoverHandler {
        id: islandHover
        enabled: root.clickable
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
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
        // Icons must not steal taps from TapHandler.
        enabled: !root.clickable
        anchors.fill: parent
        anchors.leftMargin: Theme.barIslandPadH
        anchors.rightMargin: Theme.barIslandPadH
        anchors.topMargin: Theme.barIslandPadV
        anchors.bottomMargin: Theme.barIslandPadV
        spacing: 8
    }
}
