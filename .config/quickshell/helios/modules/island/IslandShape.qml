import QtQuick
import QtQuick.Shapes
import "../../services"
import "../../components"

// The island's background — Apple-style vibrancy material: a translucent
// surface with subtle gradient depth and soft inner shadow. The pill floats
// off the screen edge (Island.qml's margins.top) so all four corners'
// continuous rounding is visible.
Item {
    id: root

    property bool liquidGlassEnabled: Config.islandGlassActive
    // Colors.surface everywhere except idle mode (Island.qml passes
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
    // Notch: the shape reaches up through `attachGap` to the screen edge,
    // its top corners run past it (the surface clips them), and concave
    // fillets join the sides to the edge.
    property bool attached: false
    property real attachGap: 0
    readonly property real attachReach: attached ? attachGap + cornerRadius : 0
    property real radiusLimit: expanded ? Config.islandExpandedCornerRadius : Config.islandIdleCornerRadius
    // Keep corners within the shape as it morphs between Idle and Expanded.
    readonly property real cornerRadius: Math.max(0, Math.min(width / 2, height / 2, radiusLimit))

    // Joins one side to the screen edge. Solid fill only: it can't match
    // the glass blur, so glass drops it.
    component Fillet: ConcaveCorner {
        size: root.cornerRadius
        color: root.fillColor
        visible: root.attached && !root.liquidGlassEnabled && size > 0
        // The parent Item starts at the screen edge minus cornerRadius.
        y: size
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: -root.attachReach
        // Shadow fades with the fill, as on the Dock, so it doesn't darken a
        // translucent island.
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

        // 1 px into the body: two antialiased edges meeting exactly let
        // the wallpaper through as a hairline at fractional scales.
        Fillet { x: 1 - size; corner: "topRight" }
        Fillet { x: root.width - 1; corner: "topLeft" }
    }

    SurfaceBorder {
        anchors.fill: parent
        anchors.topMargin: -root.attachReach
        visible: root.borderEnabled
        radius: root.cornerRadius
        border.width: root.borderWidth
        tint: Config.islandBorderColor
        tintOpacity: Config.islandBorderOpacity
    }
}
