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
    // A notch keeps straight sides between its shoulders and corners, so it
    // hangs from the edge instead of reading as a pill.
    readonly property real cornerRadius: Math.max(0, Math.min(width / 2, attached ? height * 0.375 : height / 2, radiusLimit))
    // The concave curves joining a notch to the screen edge, a little
    // tighter than the corners below them.
    readonly property real shoulderRadius: root.cornerRadius * 0.75

    readonly property bool notched: root.attached && root.shoulderRadius > 0

    // The notch outline as one path: body plus both shoulders. Drawing the
    // shoulders as separate pieces leaves an antialiased seam where they meet
    // the body, and any overlap to hide it bends the curve off its tangent.
    // Coordinates are surface-relative shifted right by s; the screen edge
    // sits at y = r.
    component NotchFill: Shape {
        id: notchFill
        property bool glassFill: false
        readonly property real r: root.cornerRadius
        readonly property real s: root.shoulderRadius
        readonly property real w: root.width
        readonly property real h: surface.height
        x: -s
        width: w + 2 * s
        height: h
        visible: root.notched && opacity > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: root.fillColor
            fillGradient: notchFill.glassFill ? glassTint : null
            startX: 0; startY: notchFill.r
            PathLine { x: notchFill.w + 2 * notchFill.s; y: notchFill.r }
            PathArc { x: notchFill.w + notchFill.s; y: notchFill.r + notchFill.s; radiusX: notchFill.s; radiusY: notchFill.s; direction: PathArc.Counterclockwise }
            PathLine { x: notchFill.w + notchFill.s; y: notchFill.h - notchFill.r }
            PathArc { x: notchFill.w + notchFill.s - notchFill.r; y: notchFill.h; radiusX: notchFill.r; radiusY: notchFill.r }
            PathLine { x: notchFill.s + notchFill.r; y: notchFill.h }
            PathArc { x: notchFill.s; y: notchFill.h - notchFill.r; radiusX: notchFill.r; radiusY: notchFill.r }
            PathLine { x: notchFill.s; y: notchFill.r + notchFill.s }
            PathArc { x: 0; y: notchFill.r; radiusX: notchFill.s; radiusY: notchFill.s; direction: PathArc.Counterclockwise }
        }
    }
    readonly property LinearGradient glassTint: LinearGradient {
        x1: 0; y1: 0; x2: 0; y2: surface.height
        GradientStop { position: 0; color: glass.topTint }
        GradientStop { position: 1; color: glass.bottomTint }
    }

    // Blur regions are whole-pixel, so their curves step. Keeping them this
    // far inside the antialiased paint hides the steps under the tint.
    readonly property int blurInset: 2

    // The painted body (reaching up through attachGap when attached), inset
    // for blur, plus the shoulder squares and the circles their concave
    // edges follow, grown by the same inset. Windows build their
    // BackgroundEffect blur region from these.
    readonly property alias surface: surface
    readonly property alias blurBody: blurBody
    readonly property real blurRadius: Math.max(0, root.cornerRadius - root.blurInset)
    readonly property Item leftFillet: root.notched ? leftFilletBlur : null
    readonly property Item rightFillet: root.notched ? rightFilletBlur : null
    readonly property alias leftFilletCut: leftFilletCut
    readonly property alias rightFilletCut: rightFilletCut

    Item {
        id: surface
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
            id: glass
            anchors.fill: parent
            active: root.liquidGlassEnabled
            cornerRadius: root.cornerRadius
            fallbackColor: root.fillColor
            // The surface starts cornerRadius above the screen edge; the
            // shoulders cover the next shoulderRadius of each side.
            rimTopInset: root.notched ? root.cornerRadius + root.shoulderRadius : 0
            fillShown: !root.notched
        }

        // Solid and glass cross-fade, as LiquidGlassSurface does.
        NotchFill { opacity: 1 - glass.glassAmount }
        NotchFill { opacity: glass.glassAmount; glassFill: true }

        // Shoulder squares sit beside the body from the screen edge down;
        // each arc's circle is centred on the square's outer bottom corner.
        readonly property real shoulderTop: root.cornerRadius
        readonly property real s: root.shoulderRadius
        Item { id: leftFilletCut; x: -2 * parent.s - root.blurInset; y: parent.shoulderTop - root.blurInset; width: 2 * (parent.s + root.blurInset); height: width }
        Item { id: rightFilletCut; x: root.width - root.blurInset; y: parent.shoulderTop - root.blurInset; width: 2 * (parent.s + root.blurInset); height: width }
        Item { id: blurBody; anchors.fill: parent; anchors.margins: root.blurInset }
        // Widened into the body so they meet the inset blurBody.
        Item { id: leftFilletBlur; x: -parent.s; y: parent.shoulderTop; width: parent.s + root.blurInset; height: parent.s }
        Item { id: rightFilletBlur; x: root.width - root.blurInset; y: parent.shoulderTop; width: parent.s + root.blurInset; height: parent.s }
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
