import QtQuick
import QtQuick.Effects

// material.shell v2 (ADR-0005): a thin transparent satin-glass plate.
// The environment reads through it; the compositor provides the blur
// (Hyprland layerrule on the surface's layer namespace).
// The edge is a single soft lens falloff (not stacked 1px frames).
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
        // Never clip this fill: Qt clip is a bounding rectangle, and the tinted
        // corner ears get Hyprland frost — a square poking out of the radius.
        // Content stays here (no layer) so type stays sharp.

        // Sheen/lift/noise only: mask to the radius without putting text through
        // a filtered layer (that made the whole plate look soapy).
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

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                    GradientStop { position: 0.40; color: Qt.rgba(1, 1, 1, 0.015) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.03) }
                }
            }

            Rectangle {
                width: parent.width * 1.8
                height: parent.height * 0.6
                x: -parent.width * 0.3
                y: -parent.height * 0.12
                rotation: -16
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Tokens.sheen }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../assets/satin-noise.png")
                fillMode: Image.Tile
                opacity: Tokens.noiseOpacity
                smooth: true
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 48
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
                }
            }
        }

        Item {
            id: inner
            anchors.fill: parent
        }
    }

    // Edge = thickness: one SDF lens band, inset so corners stay clean.
    GlassEdge {
        anchors.fill: pane
        radius: root.radius
    }
}
