import QtQuick
import QtQuick.Shapes
import "../services"

// Rolling line graph for live samples: a line with a soft area fill, plus an
// optional second line (e.g. upload next to download). Samples are drawn
// right-aligned on a fixed `capacity` grid, so a graph that is still warming
// up fills in from the right instead of stretching. Points are rebuilt only
// when `values` changes — no continuous animation.
//
// Requires an explicit `width` and `height` from the caller.
Shape {
    id: root

    property var values: [] // numeric samples, oldest first
    property var secondaryValues: []
    property int capacity: 60
    // 0 auto-scales to the largest visible sample (never below minScale).
    property real maxValue: 0
    property real minScale: 1
    property color lineColor: Colors.accent
    property color secondaryLineColor: Colors.subtext

    readonly property real strokeWidth: 1.5
    // The value drawn at the top edge.
    readonly property real peak: root.maxValue > 0
        ? root.maxValue
        : Math.max(root.minScale, root._largest(root.values), root._largest(root.secondaryValues))
    readonly property var points: root._toPoints(root.values)
    readonly property var secondaryPoints: root._toPoints(root.secondaryValues)

    function _largest(samples) {
        let largest = 0;
        for (let i = 0; i < samples.length; i++)
            largest = Math.max(largest, samples[i]);
        return largest;
    }

    function _toPoints(samples) {
        const count = Math.min(samples.length, root.capacity);
        const step = root.width / Math.max(1, root.capacity - 1);
        const inset = root.strokeWidth / 2;
        const span = root.height - root.strokeWidth;
        const result = [];
        for (let i = 0; i < count; i++) {
            const value = samples[samples.length - count + i];
            const ratio = Math.max(0, Math.min(1, value / root.peak));
            result.push(Qt.point(root.width - (count - 1 - i) * step, inset + span * (1 - ratio)));
        }
        return result;
    }

    preferredRendererType: Shape.CurveRenderer

    // Area under the primary line.
    ShapePath {
        strokeColor: "transparent"
        fillColor: root.points.length > 1 ? Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.18) : "transparent"

        PathPolyline { path: root.points }
        PathLine { x: root.width; y: root.height }
        PathLine { x: root.points.length > 0 ? root.points[0].x : root.width; y: root.height }
    }

    ShapePath {
        strokeColor: root.secondaryPoints.length > 1 ? root.secondaryLineColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathPolyline { path: root.secondaryPoints }
    }

    ShapePath {
        strokeColor: root.points.length > 1 ? root.lineColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.RoundCap

        PathPolyline { path: root.points }
    }
}
