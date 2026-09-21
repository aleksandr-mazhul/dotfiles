import QtQuick

// The selected row is a second, thinner sheet resting on the plate.
//
// Three layers, not six: a film of light, a lit top edge, one hairline. The
// old pill stacked two RectangularShadows, a scrim, a fill, a border, an inner
// border and a gradient — which is how a row ends up reading as a chrome widget
// instead of as glass.
Item {
    id: root

    property bool hovered: false
    property bool selected: false
    // Quieter than selected: current device / marked rows. Focus still wins.
    property bool muted: false

    readonly property int pillRadius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)
    readonly property bool showMuted: root.muted && !root.selected

    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.pillRadius
        color: root.selected
            ? GlassGrade.filmStrong
            : (root.hovered ? GlassGrade.film
                            : (root.showMuted ? GlassGrade.film : "transparent"))
        opacity: root.showMuted && !root.hovered ? 0.6 : 1

        Behavior on color {
            ColorAnimation {
                duration: (root.hovered && !root.selected) ? Tokens.stateMs : 0
                easing.type: Easing.OutCubic
            }
        }
    }

    // Light catches the top lip of the raised sheet.
    Rectangle {
        visible: root.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 1
        height: 1
        color: GlassGrade.edgeLit
    }

    Rectangle {
        visible: root.selected || root.showMuted
        anchors.fill: parent
        radius: root.pillRadius
        color: "transparent"
        border.width: 1
        border.color: GlassGrade.hairline
    }
}
