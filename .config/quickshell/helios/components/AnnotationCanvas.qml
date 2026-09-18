import QtQuick

Canvas {
    id: root

    property string backgroundSource: ""
    // Ensure this is strictly handled as a string color hex/name representation
    property string currentColor: "#e5484d"
    property var strokes: []

    readonly property bool canUndo: root.strokes.length > 0

    function newStroke(color) {
        // FIX: Force a primitive string evaluation by using `.toString()`
        // This breaks any accidental binding references to your toolbar's active color state.
        var strokeColor = (color ? color : root.currentColor).toString();
        root.strokes = root.strokes.concat([
            {
                color: strokeColor,
                points: []
            }
        ]);
    }

    function addPoint(x, y) {
        if (!root.strokes.length)
            return;
        const updated = root.strokes.slice();
        const last = updated[updated.length - 1];

        // Preserve the individual stroke's original captured color safely
        updated[updated.length - 1] = {
            color: last.color,
            points: last.points.concat([
                {
                    x: x,
                    y: y
                }
            ])
        };
        root.strokes = updated;
    }

    function undo() {
        root.strokes = root.strokes.slice(0, -1);
    }
    function clear() {
        root.strokes = [];
    }

    function saveToFile(path, onCaptured, onSaved) {
        root.grabToImage(result => {
            if (onCaptured)
                onCaptured();
            Qt.callLater(() => {
                const saved = result.saveToFile(path);
                if (onSaved)
                    onSaved(saved);
            });
        }, Qt.size(root.width, root.height));
    }

    Image {
        id: bg
        source: root.backgroundSource ? "file://" + root.backgroundSource : ""
        visible: false
        onStatusChanged: if (status === Image.Ready)
            root.requestPaint()
    }

    onStrokesChanged: root.requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (bg.status === Image.Ready)
            ctx.drawImage(bg, 0, 0, root.width, root.height);
        for (const stroke of root.strokes) {
            if (stroke.points.length < 2)
                continue;
            ctx.strokeStyle = stroke.color;
            ctx.lineWidth = 4;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
            for (let i = 1; i < stroke.points.length; i++)
                ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
            ctx.stroke();
        }
    }

    MouseArea {
        anchors.fill: parent
        // Pass root.currentColor directly to your snapshot function
        onPressed: mouse => {
            root.newStroke(root.currentColor);
            root.addPoint(mouse.x, mouse.y);
        }
        onPositionChanged: mouse => {
            if (pressed)
                root.addPoint(mouse.x, mouse.y);
        }
    }
}
