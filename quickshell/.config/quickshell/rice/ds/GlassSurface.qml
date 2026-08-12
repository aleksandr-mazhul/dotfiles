import QtQuick
import QtQuick.Effects

// material.shell v2 (ADR-0005): a thin transparent satin-glass plate.
// The environment reads through it; the compositor provides the blur
// (Hyprland layerrule on the surface's layer namespace).
// The edge is light — bright outer rim, refraction line, soft inner rim —
// which gives the plate physical thickness. Never a drawn frame.
Item {
    id: root

    property int radius: Tokens.radiusSurface
    default property alias content: inner.data

    // Shadow communicates distance, not decoration.
    RectangularShadow {
        anchors.fill: pane
        offset: Qt.vector2d(0, 20)
        radius: root.radius
        blur: 80
        spread: 0
        color: Tokens.shadow
    }

    Rectangle {
        id: pane
        anchors.fill: parent
        radius: root.radius
        color: Tokens.shellTint
        clip: true

        // Satin lift — glass catches light from above; keeps the center calm.
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.04) }
            }
        }

        // Diagonal sheen — almost imperceptible light play across the plate.
        Rectangle {
            width: parent.width * 1.8
            height: parent.height * 0.6
            x: -parent.width * 0.3
            y: -parent.height * 0.12
            rotation: -16
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.5; color: Tokens.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Micro-noise kills the "plastic" feel; imperceptible as a layer.
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/noise.png")
            fillMode: Image.Tile
            opacity: Tokens.noiseOpacity
            smooth: false
        }

        // Faint bottom shade — the lower edge of the glass volume.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 48
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
            }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    // Edge = thickness: bright rim → refraction line → soft inner rim.
    Rectangle {
        anchors.fill: pane
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: Tokens.rimOuter
    }
    Rectangle {
        anchors.fill: pane
        anchors.margins: 1
        radius: root.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Tokens.rimLine
    }
    Rectangle {
        anchors.fill: pane
        anchors.margins: 2
        radius: root.radius - 2
        color: "transparent"
        border.width: 1
        border.color: Tokens.rimInner
    }
}
