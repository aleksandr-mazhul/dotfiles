import QtQuick

// type.section — quiet uppercase group label; grouping is done by air + label,
// never by boxes (List Pattern).
QuietText {
    property string label: ""

    text: label.toUpperCase()
    color: Tokens.textTertiary
    font.family: Tokens.fontUi
    font.pixelSize: Tokens.fontSizeSection
    font.letterSpacing: Tokens.sectionTracking
}
