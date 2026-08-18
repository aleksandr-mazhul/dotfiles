import QtQuick

// Neutral glass keycap.
Rectangle {
    property string key: ""

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + 12)
    implicitHeight: 20
    radius: 6
    color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.22 + AdaptiveContrast.contrast * 0.10)

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Tokens.fieldScrim
        z: -1
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.round(parent.height * 0.45)
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    QuietText {
        id: label
        anchors.centerIn: parent
        text: key
        color: Qt.rgba(1, 1, 1, 0.78)
        font.family: Tokens.fontUi
        font.pixelSize: Tokens.fontSizeSm - 1
    }
}
