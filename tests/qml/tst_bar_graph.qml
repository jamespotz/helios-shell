import QtQuick
import Quickshell
import Quickshell.Io
import "components"
import "services"

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

    BarGraph {
        id: graph
        width: 100
        height: 50
        capacity: 5
        warnAt: 60
        hotAt: 85
    }

    function test_oneBarPerSlot() {
        root.compare(graph.barCount, 5);
    }

    function test_samplesRightAlignedWhileWarmingUp() {
        graph.values = [10, 20];
        root.compare([0, 1, 2, 3, 4].map(i => graph.valueAt(i)), [-1, -1, -1, 10, 20]);
    }

    function test_keepsNewestSamples() {
        graph.values = [1, 2, 3, 4, 5, 6, 7];
        root.compare([0, 1, 2, 3, 4].map(i => graph.valueAt(i)), [3, 4, 5, 6, 7]);
    }

    function test_levelColors() {
        root.verify(Qt.colorEqual(graph.colorFor(10), Colors.accent), "calm → accent");
        root.verify(Qt.colorEqual(graph.colorFor(60), Colors.warning), "warn threshold → warning");
        root.verify(Qt.colorEqual(graph.colorFor(90), Colors.danger), "hot → danger");
    }

    Component.onCompleted: {
        try {
            root.test_oneBarPerSlot();
            root.test_samplesRightAlignedWhileWarmingUp();
            root.test_keepsNewestSamples();
            root.test_levelColors();
            console.warn("BAR_GRAPH_TEST_PASS");
        } catch (error) {
            console.error("BAR_GRAPH_TEST_FAIL:", error.toString());
        }
        root._terminateDelay.start();
    }
}
