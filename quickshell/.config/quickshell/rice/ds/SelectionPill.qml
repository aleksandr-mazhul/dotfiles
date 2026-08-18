import QtQuick
import QtQuick.Effects

// Selected row is a second glass sheet floating on the plate.
Item {
    id: root

    property bool hovered: false
    property bool selected: false

    readonly property int pillRadius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)

    RectangularShadow {
        anchors.fill: fill
        visible: root.selected
        offset: Qt.vector2d(0, 6)
        radius: root.pillRadius
        blur: 18
        spread: 0
        color: Qt.rgba(0, 0, 0, 0.04)
    }

    RectangularShadow {
        anchors.fill: fill
        visible: root.selected
        offset: Qt.vector2d(0, 0)
        radius: root.pillRadius
        blur: 16
        spread: 0
        color: Tokens.selectGlow
    }

    Rectangle {
        anchors.fill: fill
        radius: root.pillRadius
        color: Tokens.selectScrim
        visible: root.selected
    }

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.pillRadius
        color: root.selected ? Tokens.raisedStrong : (root.hovered ? Tokens.raised : "transparent")
        border.width: root.selected ? 1 : (root.hovered ? 1 : 0)
        border.color: root.selected ? Tokens.raisedRim : Qt.rgba(1, 1, 1, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: (root.hovered && !root.selected) ? Tokens.stateMs : 0
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        visible: root.selected
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(Tokens.radiusMin, root.pillRadius - 1)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.07)
    }

    Rectangle {
        visible: root.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        anchors.topMargin: 1
        height: Math.round(parent.height * 0.42)
        radius: root.pillRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
