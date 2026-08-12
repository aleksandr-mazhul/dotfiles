import QtQuick

// material.raised v2 (ADR-0005) — hover/selection is a LIGHTER glass level with its
// own soft rim, never an accent fill. Radius stays concentric with the surface.
Rectangle {
    property bool hovered: false
    property bool selected: false

    radius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)
    color: selected ? Tokens.raisedStrong : (hovered ? Tokens.raised : "transparent")
    border.width: (selected || hovered) ? 1 : 0
    border.color: Tokens.raisedRim

    Behavior on color {
        ColorAnimation { duration: Tokens.stateMs; easing.type: Easing.OutCubic }
    }
}
