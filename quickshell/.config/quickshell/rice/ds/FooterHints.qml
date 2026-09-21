import QtQuick

// Footer is part of the plate — one hairline, compact keycaps, quiet type.
// No band behind it: a second fill here reads as a toolbar, not as glass.
Item {
    id: root

    // [{ keys: ["↑","↓"], label: "Navigate" }, …] — left side
    property var hints: []
    // right side; set to null to hide
    property var closeHint: ({ keys: ["esc"], label: "Close" })

    implicitHeight: Tokens.footerHeight

    Hairline {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        opacity: 0.85
    }

    component HintGroup: Row {
        property var hint: ({ keys: [], label: "" })
        spacing: 6

        Repeater {
            model: hint.keys
            KbdBadge {
                required property var modelData
                key: modelData
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        QuietText {
            text: hint.label
            color: GlassGrade.textSecondary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSizeSm
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.gapSection

        Repeater {
            model: root.hints
            HintGroup {
                required property var modelData
                hint: modelData
            }
        }
    }

    HintGroup {
        visible: !!root.closeHint
        hint: root.closeHint || ({ keys: [], label: "" })
        anchors.right: parent.right
        anchors.rightMargin: Tokens.rowPaddingX
        anchors.verticalCenter: parent.verticalCenter
    }
}
