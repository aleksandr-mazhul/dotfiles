import QtQuick

// A liquid glass sheet: one ShaderEffect, no stacked frames or shadow items.
//
// Everything the old GlassSurface drew with Rectangles — outer rim, inner rim,
// sheen gradient, two RectangularShadows — is now one pass of liquidglass.frag,
// because those are all the same physical thing (one lit, refracting edge) and
// approximating it with concentric borders is what produced the thick white
// halo this replaces.
//
// The shader needs padding around the sheet for the contact shadow, so this
// item is LARGER than the glass. Children are laid out against `surface`, which
// is the sheet itself; `content` does that for you.
Item {
    id: root

    property GlassBackdrop backdrop: null
    property int radius: Tokens.radiusSurface

    // The sheet, inset from this item by the shadow padding.
    readonly property alias surface: surfaceItem
    readonly property int pad: Math.round(GlassGrade.pad)

    // Children are placed on the sheet, not in the padding ring.
    default property alias content: surfaceItem.data

    // Hosts size themselves to the glass; the padding is this item's own.
    property int glassWidth: 0
    property int glassHeight: 0
    implicitWidth: glassWidth + 2 * pad
    implicitHeight: glassHeight + 2 * pad

    // Where this item sits inside the backdrop (i.e. the window), in px.
    // Supplied by the host rather than derived with mapToItem(): mapToItem is a
    // plain function call, so a binding using it never re-evaluates when an
    // ancestor moves, and the refraction silently samples the wrong pixels.
    property real originX: 0
    property real originY: 0

    ShaderEffect {
        id: sheet
        anchors.fill: parent
        blending: true
        supportsAtlasTextures: false
        visible: !!root.backdrop && root.backdrop.hasContent

        property real itemW: width
        property real itemH: height
        // Plate rect -> capture uv. The backdrop fills the window, so window
        // coordinates are source coordinates.
        readonly property real srcSpanW: root.backdrop ? Math.max(1, root.backdrop.width) : 1
        readonly property real srcSpanH: root.backdrop ? Math.max(1, root.backdrop.height) : 1
        property real srcX: root.originX / srcSpanW
        property real srcY: root.originY / srcSpanH
        property real srcW: width / srcSpanW
        property real srcH: height / srcSpanH

        property real pad: root.pad
        property real radius: root.radius
        property real corner: GlassGrade.cornerPower
        property real bevel: GlassGrade.bevel
        property real lens: GlassGrade.lens
        property real disperse: GlassGrade.disperse
        property real absorb: GlassGrade.absorb
        property real veil: GlassGrade.veil
        property real satur: GlassGrade.satur
        property real lipWidth: GlassGrade.lipWidth
        property real bodyTilt: GlassGrade.bodyTilt
        property real specA: GlassGrade.specA
        property real lipDarkA: GlassGrade.lipDarkA
        property real causticA: GlassGrade.causticA
        property real innerA: GlassGrade.innerA
        property real shadowA: GlassGrade.shadowA
        property real shadowSize: GlassGrade.shadowSize
        property real blurTexelX: root.backdrop ? root.backdrop.blurTexelX : 0
        property real blurTexelY: root.backdrop ? root.backdrop.blurTexelY : 0

        property variant sharpTex: root.backdrop ? root.backdrop.sharp : null
        property variant blurTex: root.backdrop ? root.backdrop.blur : null

        fragmentShader: Qt.resolvedUrl("liquidglass.frag.qsb")
        vertexShader: Qt.resolvedUrl("liquidglass.vert.qsb")
    }

    // Without a capture there is nothing to refract. Degrade to a plain
    // translucent sheet instead of rendering empty samplers as a black slab.
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: !sheet.visible
        radius: root.radius
        color: Qt.rgba(0, 0, 0, 0.62)
        border.width: 1
        border.color: GlassGrade.hairline
    }

    Item {
        id: surfaceItem
        x: root.pad
        y: root.pad
        width: Math.max(0, root.width - 2 * root.pad)
        height: Math.max(0, root.height - 2 * root.pad)
    }
}
