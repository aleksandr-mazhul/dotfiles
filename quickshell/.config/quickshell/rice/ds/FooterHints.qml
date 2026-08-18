import QtQuick

// Footer is part of the smoked plate — hairline, compact keycaps, quiet type.
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
        Text {
            text: hint.label
            color: Tokens.textSecondary
            font.family: Tokens.fontUi
            font.pixelSize: Tokens.fontSizeSm
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.22)
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
