import QtQuick
import QtQuick.Shapes
import "../services"

// Wavy tether from the orbit center to one orbiting card — an S-shaped
// cubic curve whose control points sway perpendicular to the straight
// line between hub and card, so it reads as a loose cord rather than a
// rigid spoke. Driven by a shared wavePhase from the caller (one timer
// for every rope) plus a per-rope phaseOffset so ropes sway out of sync.
Shape {
    id: root

    required property real targetX
    required property real targetY
    required property real wavePhase
    property real phaseOffset: 0
    property real amplitude: 28

    readonly property real originX: width / 2
    readonly property real originY: height / 2
    readonly property real dist: Math.hypot(targetX, targetY)
    readonly property real perpX: dist > 0 ? -targetY / dist : 0
    readonly property real perpY: dist > 0 ? targetX / dist : 0
    readonly property real sway1: amplitude * Math.sin(wavePhase + phaseOffset)
    readonly property real sway2: amplitude * Math.sin(wavePhase + phaseOffset + Math.PI)

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: 2
        strokeColor: Qt.rgba(Colors.overlay.r, Colors.overlay.g, Colors.overlay.b, 0.3)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        strokeStyle: ShapePath.SolidLine

        startX: root.originX
        startY: root.originY

        PathCubic {
            x: root.originX + root.targetX
            y: root.originY + root.targetY
            control1X: root.originX + root.targetX / 3 + root.perpX * root.sway1
            control1Y: root.originY + root.targetY / 3 + root.perpY * root.sway1
            control2X: root.originX + root.targetX * 2 / 3 + root.perpX * root.sway2
            control2Y: root.originY + root.targetY * 2 / 3 + root.perpY * root.sway2
        }
    }
}
