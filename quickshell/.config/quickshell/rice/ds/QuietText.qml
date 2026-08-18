import QtQuick

// White UI type with a 1px drop shadow instead of a hard outline.
Item {
    id: root

    property alias text: fg.text
    property alias color: fg.color
    property alias font: fg.font
    property int elide: Text.ElideNone
    property int wrapMode: Text.NoWrap
    property int horizontalAlignment: Text.AlignLeft
    property int verticalAlignment: Text.AlignVCenter
    property int maximumLineCount: 1
    property bool fontBold: false
    property int fontWeight: Font.Normal

    implicitWidth: fg.implicitWidth
    implicitHeight: Math.max(fg.implicitHeight, fg.font.pixelSize + 4)
    width: implicitWidth
    height: implicitHeight

    Text {
        id: sh
        x: fg.x
        y: fg.y + 1
        width: fg.width
        height: fg.height
        text: fg.text
        font: fg.font
        elide: fg.elide
        wrapMode: fg.wrapMode
        maximumLineCount: fg.maximumLineCount
        horizontalAlignment: fg.horizontalAlignment
        verticalAlignment: fg.verticalAlignment
        color: Tokens.textShadow
        visible: fg.text.length > 0
        z: 0
    }

    Text {
        id: fg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        elide: root.elide
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        font.weight: root.fontWeight
        font.bold: root.fontBold
        z: 1
    }
}
