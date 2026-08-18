import QtQuick

// material.raised v2 (ADR-0005) — hover/selection is a LIGHTER glass level.
// Soft fill, hairline rim — never a dark boxed stroke.
Rectangle {
    property bool hovered: false
    property bool selected: false

    radius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)
    color: selected ? Tokens.raisedStrong : (hovered ? Tokens.raised : "transparent")
    border.width: (selected || hovered) ? 1 : 0
    border.color: selected ? Tokens.raisedRim : Qt.rgba(1, 1, 1, 0.08)

    Behavior on color {
        ColorAnimation {
            // Keyboard selection must paint in the same frame as the list snap.
            // Animate only hover, or the pill lags behind the scroll.
            duration: (hovered && !selected) ? Tokens.stateMs : 0
            easing.type: Easing.OutCubic
        }
    }
}
