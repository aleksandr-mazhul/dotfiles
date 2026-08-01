pragma Singleton
import QtQuick

QtObject {
    readonly property color background: Colors.background
    readonly property color surface: Colors.surface
    readonly property color surfaceContainer: Colors.surface_container
    readonly property color surfaceVariant: Colors.surface_variant
    readonly property color primary: Colors.primary
    readonly property color secondary: Colors.secondary
    readonly property color onBackground: Colors.on_background
    readonly property color onSurface: Colors.on_surface
    readonly property color onPrimary: Colors.on_primary
    readonly property color outline: Colors.outline
    readonly property color error: Colors.error

    readonly property int radiusLg: 18
    readonly property int radiusMd: 12
    readonly property int radiusSm: 8
    readonly property int panelWidth: 560
    readonly property int panelMaxHeight: 520
    readonly property int rowHeight: 52
    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 14
    readonly property int fontSizeSm: 12
    readonly property int fontSizeLg: 16
}
