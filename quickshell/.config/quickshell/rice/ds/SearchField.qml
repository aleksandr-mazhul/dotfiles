import QtQuick
import ".."

// The search field is the visual anchor of a popup: a sheet inset INTO the
// plate, read as a groove rather than as a bordered input box. A groove is one
// film, one shaded top edge and one lit bottom edge — the inverse of the raised
// SelectionPill, which is what makes the two read as different depths.
Item {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: "Search…"
    // Invocation shortcut of this surface, e.g. ["alt", "O"]; hidden while typing.
    property var hintKeys: []
    // Forward keys to the popup's handler.
    property var keyHandler: null
    property bool pointerHidden: false

    implicitHeight: Tokens.searchFieldHeight

    Rectangle {
        id: field
        anchors.fill: parent
        radius: Tokens.radiusField
        color: GlassGrade.film
        border.width: 1
        border.color: input.activeFocus ? GlassGrade.focusRim : GlassGrade.hairline

        Behavior on border.color {
            ColorAnimation { duration: Tokens.stateMs; easing.type: Easing.OutCubic }
        }

        // Inset: shaded at the top where the plate overhangs it, lit at the
        // bottom where light reaches the far wall of the groove.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            color: GlassGrade.edgeShade
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 1
            height: 1
            color: GlassGrade.edgeLit
            opacity: 0.7
        }
    }

    RiceIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Tokens.paddingFieldX
        anchors.verticalCenter: parent.verticalCenter
        customSource: Qt.resolvedUrl("../assets/search.svg")
        tint: GlassGrade.textIcon
        implicitSize: 16
        halo: true
        haloColor: GlassGrade.textHalo
    }

    TextInput {
        id: input
        anchors.left: icon.right
        anchors.leftMargin: Tokens.gapInline
        anchors.right: hintRow.visible ? hintRow.left : parent.right
        anchors.rightMargin: Tokens.paddingFieldX
        anchors.verticalCenter: parent.verticalCenter
        color: GlassGrade.textPrimary
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSize
        clip: true
        selectionColor: GlassGrade.filmStrong
        selectedTextColor: GlassGrade.textPrimary

        QuietText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: GlassGrade.textTertiary
            font: input.font
            visible: input.text.length === 0
        }

        Keys.onPressed: event => {
            if (typeof root.keyHandler === "function" && root.keyHandler(event))
                event.accepted = true
        }
    }

    HoverHandler {
        enabled: root.pointerHidden
        cursorShape: Qt.BlankCursor
    }

    Row {
        id: hintRow
        visible: input.text.length === 0 && root.hintKeys.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Tokens.paddingFieldX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: root.hintKeys
            KbdBadge {
                required property var modelData
                key: modelData
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
