import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }

    Window {
        visible: true
        width: 100
        height: 100

        AnnotationCanvas {
            id: canvas
            anchors.fill: parent
        }
    }

    Timer {
        interval: 100
        running: true
        onTriggered: {
            canvas.newStroke("#ff0000");
            canvas.addPoint(1, 1);
            canvas.addPoint(2, 2);
            canvas.newStroke("#00ff00");
            canvas.addPoint(5, 5);

            const beforeUndo = canvas.strokes.length === 2
                && canvas.strokes[0].color === "#ff0000"
                && canvas.strokes[0].points.length === 2
                && canvas.canUndo;

            canvas.undo();
            const afterUndo = canvas.strokes.length === 1;

            canvas.clear();
            const afterClear = canvas.strokes.length === 0 && !canvas.canUndo;

            if (!beforeUndo || !afterUndo || !afterClear) {
                console.error("ANNOTATION_CANVAS_TEST_FAIL");
                root.terminator.running = true;
                return;
            }

            canvas.newStroke("#ff0000");
            canvas.addPoint(1, 1);
            canvas.addPoint(20, 20);
            canvas.saveToFile("/tmp/helios-annotation-canvas-test.png", null,
                saved => {
                    if (saved)
                        console.warn("ANNOTATION_CANVAS_TEST_PASS");
                    else
                        console.error("ANNOTATION_CANVAS_TEST_FAIL save");
                    root.terminator.running = true;
                });
        }
    }
}
