import QtQuick
import QtQuick.Effects

// Neutral optical glass: frost in the compositor, light only at the rim.
// Center stays empty so wallpaper color reads through. Text is not in this layer.
Item {
    id: root

    property int radius: Tokens.radiusSurface
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: pane
        offset: Qt.vector2d(0, 8)
        radius: root.radius
        blur: 36
        spread: 0
        color: Tokens.shadow
    }

    RectangularShadow {
        anchors.fill: pane
        offset: Qt.vector2d(0, 0)
        radius: root.radius
        blur: 16
        spread: 0
        color: Qt.rgba(1, 1, 1, 0.025)
    }

    Rectangle {
        id: decoMask
        anchors.fill: pane
        radius: root.radius
        color: "#ffffff"
        visible: false
        layer.enabled: true
    }

    Rectangle {
        id: pane
        anchors.fill: parent
        radius: root.radius
        color: Tokens.shellTint
        // Never clip this fill: Qt clip frosts square ears outside the radius.

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: decoMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0
            }

            GlassEdge {
                anchors.fill: parent
                radius: root.radius
            }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors.fill: pane
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: Tokens.rimInner
    }

    Rectangle {
        anchors.fill: pane
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Tokens.rimOuter
    }
}
