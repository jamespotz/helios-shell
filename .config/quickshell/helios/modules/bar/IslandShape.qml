import QtQuick
import "../../services"
import "../../components"

// The island's background — Apple-style vibrancy material: a translucent
// surface with subtle gradient depth and soft inner shadow. The pill floats
// off the screen edge (Bar.qml's margins.top) so all four corners'
// continuous rounding is visible.
Item {
    id: root

    property bool liquidGlassEnabled: Config.islandGlassActive
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
    // Settings > Island.
    property real shadowGlowRadius: Config.islandShadowGlowRadius
    property real shadowSpread: Config.islandShadowSpread
    // Satellites pass their own border toggle and width.
    property bool borderEnabled: Config.islandBorder
    property real borderWidth: Config.islandBorderWidth

    property bool expanded: false
    property real radiusLimit: expanded ? Config.islandExpandedCornerRadius : Config.islandIdleCornerRadius
    // Keep corners within the shape as it morphs between Idle and Expanded.
    readonly property real cornerRadius: Math.max(0, Math.min(width / 2, height / 2, radiusLimit))

    // Shadow fades with the fill, as on the Dock, so it doesn't darken a
    // translucent island.
    Item {
        anchors.fill: parent
        opacity: Config.islandBackgroundOpacity

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

    SurfaceBorder {
        anchors.fill: parent
        visible: root.borderEnabled
        radius: root.cornerRadius
        border.width: root.borderWidth
        tint: Config.islandBorderColor
        tintOpacity: Config.islandBorderOpacity
    }
}
