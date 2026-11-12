import QtQuick
import QtQuick.Shapes

// A square of `size` minus a quarter circle, leaving the fill in one
// corner with a concave edge. Rounds a screen corner, or joins a shape to
// an edge. `corner` names where the fill sits.
Shape {
    id: root
    property real size: 0
    property string corner: "topLeft"
    property color color: "black"

    width: size
    height: size
    // Drawn for topLeft, then turned about the centre for the others.
    rotation: ({ topLeft: 0, topRight: 90, bottomRight: 180, bottomLeft: 270 })[root.corner]
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillColor: root.color
        startX: 0; startY: 0
        PathLine { x: root.size; y: 0 }
        PathArc {
            x: 0; y: root.size
            radiusX: root.size; radiusY: root.size
            direction: PathArc.Counterclockwise
        }
    }
}
