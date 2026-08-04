pragma Singleton
import QtQuick

// Semantic UI palette for all RicePanel overlays.
// Surfaces follow wallpaper; sand accents are pinned in Colors.qml.
QtObject {
    // Surfaces — slightly elevated so rows separate from the panel
    readonly property color background: Colors.background
    readonly property color surface: Colors.surface_container
    readonly property color surfaceContainer: Colors.surface_container_high
    readonly property color surfaceVariant: Colors.surface_variant

    // Accents — warm sand palette (not wallpaper-derived)
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
    // Kept low: this sits BEHIND the glass panel inside the same window buffer,
    // so its alpha stacks with glassBackground (0.80) before Hyprland ever blurs
    // it — anything much higher makes the "glass" panel read as a flat opaque
    // box. ~0.12 still dims the click-away area without smothering the glass.
    readonly property color backdrop: Qt.rgba(0, 0, 0, 0.12)

    // Liquid glass — match kitty background_opacity 0.80; Hyprland blur frosts behind
    readonly property real glassOpacity: 0.80
    readonly property color glassBackground: Qt.rgba(background.r, background.g, background.b, glassOpacity)
    readonly property color glassSurface: Qt.rgba(surface.r, surface.g, surface.b, 0.42)
    readonly property color glassSurfaceHover: Qt.rgba(surface.r, surface.g, surface.b, 0.55)
    readonly property color glassBorder: Qt.rgba(outline.r, outline.g, outline.b, 0.20)
    readonly property color glassBorderSubtle: Qt.rgba(outline.r, outline.g, outline.b, 0.12)
    readonly property color glassTileActive: Qt.rgba(primary.r, primary.g, primary.b, 0.26)
    readonly property color glassTileActiveHover: Qt.rgba(primary.r, primary.g, primary.b, 0.34)
    readonly property color glassTileBorder: Qt.rgba(primary.r, primary.g, primary.b, 0.32)
    readonly property color glassTrack: Qt.rgba(surfaceVariant.r, surfaceVariant.g, surfaceVariant.b, 0.45)
    readonly property color glassFill: Qt.rgba(primary.r, primary.g, primary.b, 0.78)

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
    // Chrome SSOT — highlight / panel / muted (same language as tmux + starship)
    readonly property color chromeHighlightBg: Colors.chrome_highlight_bg
    readonly property color chromeHighlightFg: Colors.chrome_highlight_fg
    readonly property color chromePanelBg: Colors.chrome_panel_bg
    readonly property color chromePanelFg: Colors.chrome_panel_fg
    readonly property color chromeMutedBg: Colors.chrome_muted_bg
    readonly property color chromeMutedFg: Colors.chrome_muted_fg

    readonly property string fontFamily: Colors.font_mono
    readonly property string fontUi: Colors.font_ui
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
    readonly property int qsPanelHeight: 560
    // Gap under the bar strip. When the bar pins an exclusive zone, only this
    // gap is needed (zone already clears the pills). Unpinned: clear full bar.
    readonly property int qsPanelGap: 4
    // Spring-like open: long enough to read the overshoot, still snappy.
    readonly property int menuAnimMs: 220
    // Quick, no-overshoot close — panels should feel like they're dismissed, not bounced.
    readonly property int menuCloseMs: 140
    // Easing.OutBack overshoot factor for the open-scale animation.
    readonly property real menuOvershoot: 1.4
    // Shared hover/press color-transition duration (SSOT for every Behavior on color).
    readonly property int hoverMs: 120
}
