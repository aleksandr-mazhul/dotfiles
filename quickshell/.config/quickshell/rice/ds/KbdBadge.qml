import QtQuick

// Key-cap hint v2 (ADR-0005) — a light glass chip (material.field) with a soft rim.
// Same light language as the plate. It is a caption, not a button: no hover, no motion.
Rectangle {
    property string key: ""

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 12)
    implicitHeight: 22
    radius: Tokens.radiusMin
    color: Tokens.fieldFill
    border.width: 1
    border.color: Tokens.fieldRim

    Text {
        id: label
        anchors.centerIn: parent
        text: key
        color: Tokens.textSecondary
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSizeSm - 1
    }
}
