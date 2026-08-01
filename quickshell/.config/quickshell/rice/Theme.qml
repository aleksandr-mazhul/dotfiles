pragma Singleton
import QtQuick

// Semantic UI palette for all RicePanel overlays.
// Keeps matugen accents, but forces readable contrast on dark panels.
QtObject {
    // Surfaces — slightly elevated so rows separate from the panel
    readonly property color background: Colors.background
    readonly property color surface: Colors.surface_container
    readonly property color surfaceContainer: Colors.surface_container_high
    readonly property color surfaceVariant: Colors.surface_variant

    // Accents from wallpaper
    readonly property color primary: Colors.primary
    readonly property color secondary: Colors.secondary
    readonly property color error: Colors.error

    // Text — high contrast (never dark-on-dark)
    readonly property color text: Colors.text
    readonly property color textMuted: Colors.text_muted
    readonly property color textOnAccent: Colors.text_on_primary

    // Borders / chrome
    readonly property color outline: Colors.outline
    readonly property color outlineSubtle: Colors.outline_variant
    readonly property color border: Qt.rgba(primary.r, primary.g, primary.b, 0.35)
    readonly property color borderSubtle: Qt.rgba(outline.r, outline.g, outline.b, 0.45)
    readonly property color backdrop: Qt.rgba(0, 0, 0, 0.45)

    // Row states
    readonly property color row: surfaceContainer
    readonly property color rowSelected: primary
    readonly property color rowHover: Qt.rgba(primary.r, primary.g, primary.b, 0.18)

    // Back-compat aliases used across panels
    readonly property color onSurface: text
    readonly property color onPrimary: textOnAccent
    readonly property color onBackground: text

    readonly property int radiusLg: 18
    readonly property int radiusMd: 12
    readonly property int radiusSm: 10
    readonly property int panelWidth: 920
    readonly property int panelHeight: 520
    readonly property int panelMaxHeight: 520
    readonly property int clipboardWidth: panelWidth // alias — same overlay width everywhere
    readonly property int clipboardHeight: 560
    readonly property int rowHeight: 52
    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 14
    readonly property int fontSizeSm: 12
    readonly property int fontSizeLg: 16

    // Top bar islands
    readonly property int barHeight: 36
    readonly property int barMargin: 8
    readonly property int barIslandRadius: 20
    readonly property int barIslandPadH: 12
    readonly property int barIslandPadV: 6
    readonly property int barGap: 8
    readonly property int qsPanelWidth: 380
}
