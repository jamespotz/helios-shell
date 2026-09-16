import QtQuick
import "../../services"
import "../../components"

// The island's background — Apple-style vibrancy material: a translucent
// surface with subtle gradient depth and soft inner shadow. The pill floats
// off the screen edge (Bar.qml's margins.top) so all four corners'
// continuous rounding is visible.
Item {
    id: root

    property bool liquidGlassEnabled: false
    // Colors.surface everywhere except idle mode (Bar.qml passes
    // Colors.background there) — the compact pill blending toward pure
    // black sells the "floating notch" illusion.
    property color fillColor: Colors.surface
    property bool shadowEnabled: true
    // Satellites sit a few px from the island — its default blur and this
    // shape's own reach far enough into that gap to merge into a solid
    // bridge. Satellites pass their own smaller blur/spread (see
    // Config.satelliteShadowGlowRadius/Spread) so the shadow stays legible
    // without touching the island's. Defaults are user-tunable from
    // IslandSettings' "Behavior" section.
    property real shadowGlowRadius: Config.islandShadowGlowRadius
    property real shadowSpread: Config.islandShadowSpread

    // Apple's continuous corner (squircle) can't be done in pure QML
    // without ShaderEffect, but a generous radius relative to height
    // gets close. Stadium for small pills, capped for tall panels.
    readonly property real cornerRadius: Math.max(6, Math.min(height / 2, 18))

    SurfaceShadow {
        anchors.fill: parent
        cornerRadius: root.cornerRadius
        visible: root.shadowEnabled
        glowRadius: root.shadowGlowRadius
        spread: root.shadowSpread
    }

    LiquidGlassSurface {
        anchors.fill: parent
        active: root.liquidGlassEnabled
        cornerRadius: root.cornerRadius
        fallbackColor: root.fillColor
    }
}
