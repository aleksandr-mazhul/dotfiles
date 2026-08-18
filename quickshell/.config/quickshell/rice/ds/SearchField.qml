import QtQuick
import ".."

// Search Pattern v2 (ADR-0005): the search field is the visual anchor of a popup —
// a lighter glass level (material.field) on the plate, glass-in-glass.
// Same light language as the plate: soft rim, no drawn frame.
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
        radius: Tokens.innerRadius(Tokens.radiusSurface, Tokens.paddingSurface)
        color: Tokens.fieldFill
        border.width: 1
        border.color: Tokens.fieldRim
    }

    RiceIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Tokens.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        customSource: Qt.resolvedUrl("../assets/search.svg")
        tint: Tokens.textTertiary
        implicitSize: 16
    }

    TextInput {
        id: input
        anchors.left: icon.right
        anchors.leftMargin: Tokens.gapInline
        anchors.right: hintRow.visible ? hintRow.left : parent.right
        anchors.rightMargin: Tokens.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.textPrimary
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSize
        clip: true
        // Text selection stays monochrome — accent is not used in shell states.
        selectionColor: Tokens.raisedStrong
        selectedTextColor: Tokens.textPrimary

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: Tokens.textTertiary
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
        anchors.rightMargin: Tokens.rowPaddingX
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
