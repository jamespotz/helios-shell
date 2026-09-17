import QtQuick
import "../services"

// Cubic-bezier-style editor — P0=(0,0) and P3=(1,1) are fixed (Hyprland's
// curve model only exposes the two control points), draggable handles for
// visual editing, numeric fields alongside for precise entry.
Item {
    id: root

    property real p1x: 0.25
    property real p1y: 0.1
    property real p2x: 0.25
    property real p2y: 1.0

    signal pointsChanged(real p1x, real p1y, real p2x, real p2y)

    implicitWidth: 300
    implicitHeight: 200

    readonly property int padSize: 160

    function commit() { root.pointsChanged(root.p1x, root.p1y, root.p2x, root.p2y); }

    Row {
        spacing: 20

        Rectangle {
            id: pad
            width: root.padSize
            height: root.padSize
            radius: Colors.radiusSmall
            color: Colors.surface

            // Diagonal reference line (linear curve) for visual anchoring
            Rectangle {
                width: parent.width * Math.SQRT2
                height: 1
                color: Colors.overlay
                opacity: 0.3
                anchors.centerIn: parent
                rotation: -45
            }

            Canvas {
                id: curveCanvas
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.strokeStyle = Colors.accent;
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (let t = 0; t <= 1; t += 0.02) {
                        const mt = 1 - t;
                        const x = 3 * mt * mt * t * root.p1x + 3 * mt * t * t * root.p2x + t * t * t;
                        const y = 3 * mt * mt * t * root.p1y + 3 * mt * t * t * root.p2y + t * t * t;
                        ctx.lineTo(x * width, height - y * height);
                    }
                    ctx.stroke();
                }
            }
            Connections {
                target: root
                function onP1xChanged() { curveCanvas.requestPaint(); }
                function onP1yChanged() { curveCanvas.requestPaint(); }
                function onP2xChanged() { curveCanvas.requestPaint(); }
                function onP2yChanged() { curveCanvas.requestPaint(); }
            }
            Component.onCompleted: curveCanvas.requestPaint()

            component Handle: Rectangle {
                id: handle
                required property real px
                required property real py
                signal moved(real x, real y)

                width: 14
                height: 14
                radius: 7
                color: Colors.accent
                border.width: 2
                border.color: "#ffffff"
                x: handle.px * pad.width - width / 2
                y: pad.height - handle.py * pad.height - height / 2

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    drag.axis: Drag.XAndYAxis
                    onPositionChanged: {
                        if (!drag.active) return;
                        const nx = Math.max(0, Math.min(1, (handle.x + width / 2) / pad.width));
                        const ny = Math.max(0, Math.min(1, 1 - (handle.y + height / 2) / pad.height));
                        handle.moved(nx, ny);
                    }
                }
            }

            Handle {
                px: root.p1x; py: root.p1y
                onMoved: (x, y) => { root.p1x = x; root.p1y = y; root.commit(); }
            }
            Handle {
                px: root.p2x; py: root.p2y
                onMoved: (x, y) => { root.p2x = x; root.p2y = y; root.commit(); }
            }
        }

        Column {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            LabeledDecimalField { label: "P1 x"; value: root.p1x; minValue: 0; maxValue: 1; decimals: 2; onValueEdited: v => { root.p1x = v; root.commit(); } }
            LabeledDecimalField { label: "P1 y"; value: root.p1y; minValue: -1; maxValue: 2; decimals: 2; onValueEdited: v => { root.p1y = v; root.commit(); } }
            LabeledDecimalField { label: "P2 x"; value: root.p2x; minValue: 0; maxValue: 1; decimals: 2; onValueEdited: v => { root.p2x = v; root.commit(); } }
            LabeledDecimalField { label: "P2 y"; value: root.p2y; minValue: -1; maxValue: 2; decimals: 2; onValueEdited: v => { root.p2y = v; root.commit(); } }
        }
    }
}
