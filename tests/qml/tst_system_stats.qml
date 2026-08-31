import QtQuick
import Quickshell
import Quickshell.Io
import services

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
    function pass() {
        console.warn("SYSTEM_STATS_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("SYSTEM_STATS_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    function test_computeRateKBsComputesKilobytesPerSecond() {
        // 1 MB delta over 2 seconds = 512 KB/s
        root.compare(SystemStats.computeRateKBs(10, 11, 2), 512);
    }

    function test_computeRateKBsClampsNegativeDelta() {
        // Counter reset (e.g. interface restarted) must never go negative
        root.compare(SystemStats.computeRateKBs(50, 10, 1), 0);
    }

    function test_computeRateKBsHandlesZeroElapsed() {
        root.compare(SystemStats.computeRateKBs(10, 20, 0), 0);
    }

    function test_pushHistoryAppendsAndTrims() {
        root.compare(SystemStats.pushHistory([1, 2, 3], 4, 5), [1, 2, 3, 4]);
        root.compare(SystemStats.pushHistory([1, 2, 3], 4, 3), [2, 3, 4]);
        root.compare(SystemStats.pushHistory([], 1, 3), [1]);
    }

    Component.onCompleted: {
        try {
            root.test_computeRateKBsComputesKilobytesPerSecond();
            root.test_computeRateKBsClampsNegativeDelta();
            root.test_computeRateKBsHandlesZeroElapsed();
            root.test_pushHistoryAppendsAndTrims();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
