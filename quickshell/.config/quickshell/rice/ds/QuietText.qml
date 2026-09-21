import QtQuick

// UI type with a 1px drop shadow instead of a hard outline.
//
// The shadow follows THIS label's own ink, not a global: light type on a busy
// surface needs the separation, dark type does not, and a dark shadow under
// dark type only thickens the stroke. Deriving it from the colour keeps the
// rule local, so the same type serves the launcher's flipping ink and the bar's
// fixed white without either having to plumb a polarity flag through.
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

    // 1 for white ink, ~0 for dark ink.
    readonly property real inkLuma: {
        const c = fg.color
        const l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return Math.min(1, Math.max(0, (l - 0.35) / 0.35))
    }

    implicitWidth: fg.implicitWidth
    implicitHeight: Math.max(fg.implicitHeight, fg.font.pixelSize + 4)

    Text {
        id: sh2
        width: fg.width
        height: fg.height
        x: fg.x
        y: fg.y + 2
        text: fg.text
        font: fg.font
        elide: fg.elide
        wrapMode: fg.wrapMode
        maximumLineCount: fg.maximumLineCount
        horizontalAlignment: fg.horizontalAlignment
        verticalAlignment: fg.verticalAlignment
        color: Qt.rgba(0, 0, 0, (0.12 + Tokens.contrast * 0.18) * root.inkLuma)
        visible: fg.text.length > 0
        z: 0
    }

    Text {
        id: sh
        width: fg.width
        height: fg.height
        x: fg.x
        y: fg.y + 1
        text: fg.text
        font: fg.font
        elide: fg.elide
        wrapMode: fg.wrapMode
        maximumLineCount: fg.maximumLineCount
        horizontalAlignment: fg.horizontalAlignment
        verticalAlignment: fg.verticalAlignment
        color: Qt.rgba(0, 0, 0, Tokens.textShadow.a * root.inkLuma)
        visible: fg.text.length > 0
        z: 0
    }

    Text {
        id: fg
        // Do not stretch with left+right anchors: that collapses implicitWidth to 0
        // and the chip/dropdown labels vanish. Size to the host when a parent
        // (Layout / anchors) assigned a width; otherwise keep the text's own size.
        width: parent.width > 0 ? parent.width : implicitWidth
        height: parent.height > 0 ? parent.height : implicitHeight
        elide: root.elide
        wrapMode: root.wrapMode
        maximumLineCount: root.maximumLineCount
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: root.verticalAlignment
        font.weight: root.fontWeight
        font.bold: root.fontBold
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, Tokens.textHalo.a * root.inkLuma)
        z: 1
    }
}
