import QtQuick
import QtQuick.Effects

// material.shell — glossy glass experiment (this branch).
// Thin tint so the environment reads through; compositor blur (Hyprland
// layerrule, xray) frosts wallpaper. Light lives at the top edge (specular)
// and along the rim — physical thickness, not a drawn frame.
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

        // Volume: bright catch at the top, calm centre, slight bottom shade.
        Rectangle {
            anchors.fill: parent
            radius: root.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Tokens.shellLiftTop }
                GradientStop { position: 0.18; color: Tokens.shellLiftMid }
                GradientStop { position: 0.72; color: "transparent" }
                GradientStop { position: 1.0; color: Tokens.shellLiftBottom }
            }
        }

        // Specular — the glossy top-edge reflection (rounded via clip).
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(parent.height * 0.22)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Tokens.specular }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.08) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Diagonal sheen — light play across polished glass.
        Rectangle {
            width: parent.width * 1.8
            height: parent.height * 0.55
            x: -parent.width * 0.28
            y: -parent.height * 0.18
            rotation: -18
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.45; color: Tokens.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Micro-noise — quieter than satin so the surface stays glossy.
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../assets/noise.png")
            fillMode: Image.Tile
            opacity: Tokens.noiseOpacity
            smooth: false
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
