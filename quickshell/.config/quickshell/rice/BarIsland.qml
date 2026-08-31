import QtQuick
import QtQuick.Layouts
import "ds" as DS

// Island chrome + hit target. TapHandler (not MouseArea) so the bar's
// HoverHandler cannot steal presses — same open/close hitbox every time.
// Material: empty shellTint plate + dual rim. Not GlassSurface — its
// RectangularShadow/glow would weld pills across Theme.barGap.
Item {
    id: root

    property bool clickable: false
    property bool active: false
    property alias content: contentHost.data
    signal activated()

    // height/2; Theme.barIslandRadius (20) stays unused — Theme.qml untouched.
    readonly property int islandRadius: 18

    implicitHeight: Theme.barHeight
    implicitWidth: Math.max(Theme.barHeight, contentHost.implicitWidth + Theme.barIslandPadH * 2)

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
        id: pane
        anchors.fill: parent
        radius: root.islandRadius
        color: DS.Tokens.shellTint
        border.width: 1
        border.color: DS.Tokens.rimOuter
        z: -1

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: root.islandRadius - 1
            color: root.active ? DS.Tokens.raisedStrong
                : (islandHover.hovered ? DS.Tokens.raised : "transparent")
            border.width: 1
            border.color: DS.Tokens.rimInner

            Behavior on color {
                ColorAnimation {
                    duration: root.active ? 0 : DS.Tokens.stateMs
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    RowLayout {
        id: contentHost
        enabled: !root.clickable
        anchors.fill: parent
        anchors.leftMargin: Theme.barIslandPadH
        anchors.rightMargin: Theme.barIslandPadH
        anchors.topMargin: Theme.barIslandPadV
        anchors.bottomMargin: Theme.barIslandPadV
        spacing: 8
    }
}
