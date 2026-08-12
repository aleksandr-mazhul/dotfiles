import QtQuick

// Footer hints v2 (ADR-0005): a natural continuation of the glass plate —
// no band, no hairline; separation is air. Quiet but readable.
Item {
    id: root

    // [{ keys: ["↑","↓"], label: "Navigate" }, …] — left side
    property var hints: []
    // right side; set to null to hide
    property var closeHint: ({ keys: ["esc"], label: "Close" })

    implicitHeight: Tokens.footerHeight

    component HintGroup: Row {
        property var hint: ({ keys: [], label: "" })
        spacing: 8

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
