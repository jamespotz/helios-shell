import QtQuick
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    function fail(message) { throw new Error(message); }
    function verify(value, message) { if (!value) root.fail(message || "verification failed"); }
    function compare(actual, expected, message) {
        const a = JSON.stringify(actual);
        const e = JSON.stringify(expected);
        if (a !== e) root.fail((message || "values differ") + `: expected ${e}, got ${a}`);
    }
    function xy(points) { return points.map(point => [point.x, point.y]); }

    // strokeWidth 1.5 → 0.75 inset top and bottom, so height 11.5 leaves a
    // 10px plotting span; width 100 over capacity 11 is a 10px step.
    LineGraph {
        id: graph
        width: 100
        height: 11.5
        capacity: 11
    }

    function test_emptyAndSinglePoint() {
        graph.values = [];
        root.compare(graph.points, [], "no samples → no points");
        graph.maxValue = 100;
        graph.values = [50];
        root.compare(root.xy(graph.points), [[100, 5.75]], "single sample sits at the right edge");
    }

    function test_fillsFromRightOnFixedGrid() {
        graph.maxValue = 100;
        graph.values = [0, 50, 100];
        root.compare(root.xy(graph.points), [[80, 10.75], [90, 5.75], [100, 0.75]]);
    }

    function test_capacityKeepsNewestSamples() {
        graph.maxValue = 100;
        graph.values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 100];
        root.compare(graph.points.length, 11);
        root.compare(root.xy(graph.points)[0], [0, 10.55], "oldest sample dropped");
        root.compare(root.xy(graph.points)[10], [100, 0.75]);
    }

    function test_peakUsesFixedMaxOrAutoScaleWithFloor() {
        graph.maxValue = 100;
        root.compare(graph.peak, 100, "fixed max");
        graph.maxValue = 0;
        graph.minScale = 64;
        graph.values = [1, 2];
        graph.secondaryValues = [];
        root.compare(graph.peak, 64, "floor holds idle noise down");
        graph.secondaryValues = [10, 200];
        root.compare(graph.peak, 200, "auto-scale spans both series");
        root.compare(graph.secondaryPoints.length, 2);
    }

    function test_doesNotOverrideItemScale() {
        root.compare(graph.scale, 1, "Item.scale untouched");
    }

    Component.onCompleted: {
        try {
            root.test_emptyAndSinglePoint();
            root.test_fillsFromRightOnFixedGrid();
            root.test_capacityKeepsNewestSamples();
            root.test_peakUsesFixedMaxOrAutoScaleWithFloor();
            root.test_doesNotOverrideItemScale();
            console.warn("LINE_GRAPH_TEST_PASS");
        } catch (error) {
            console.error("LINE_GRAPH_TEST_FAIL:", error.toString());
        }
        root._terminateDelay.start();
    }
}
