import QtQuick

// Keycap: one film, one hairline. No scrim, no gradient — at 20px tall a
// gradient is noise, not material.
Rectangle {
    property string key: ""

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 12)
    implicitHeight: 20
    radius: 6
    color: GlassGrade.film
    border.width: 1
    border.color: GlassGrade.hairline

    QuietText {
        id: label
        anchors.centerIn: parent
        width: implicitWidth
        height: implicitHeight
        text: key
        color: GlassGrade.textSecondary
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSizeSm - 1
    }
}
