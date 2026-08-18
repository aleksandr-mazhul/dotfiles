import QtQuick
import QtQuick.Effects
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
        anchors.fill: field
        radius: Tokens.radiusField
        color: Tokens.searchScrim
    }

    RectangularShadow {
        anchors.fill: field
        offset: Qt.vector2d(0, 0)
        radius: field.radius
        blur: 14
        spread: 0
        color: Tokens.focusGlow
        opacity: input.activeFocus ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Tokens.stateMs; easing.type: Easing.OutCubic }
        }
    }

    Rectangle {
        id: field
        anchors.fill: parent
        radius: Tokens.radiusField
        color: Tokens.fieldFill
        border.width: 1
        border.color: input.activeFocus ? Tokens.focusRim : Tokens.fieldRim

        Behavior on border.color {
            ColorAnimation { duration: Tokens.stateMs; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: Math.round(parent.height * 0.42)
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    RiceIcon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Tokens.paddingFieldX
        anchors.verticalCenter: parent.verticalCenter
        customSource: Qt.resolvedUrl("../assets/search.svg")
        tint: Tokens.textIcon
        implicitSize: 16
        halo: true
        haloColor: Tokens.iconHalo
    }

    TextInput {
        id: input
        anchors.left: icon.right
        anchors.leftMargin: Tokens.gapInline
        anchors.right: hintRow.visible ? hintRow.left : parent.right
        anchors.rightMargin: Tokens.paddingFieldX
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.textPrimary
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSize
        clip: true
        selectionColor: Tokens.raisedStrong
        selectedTextColor: Tokens.textPrimary

        QuietText {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            text: root.placeholder
            color: Qt.rgba(1, 1, 1, 0.58 + Tokens.contrast * 0.12)
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
