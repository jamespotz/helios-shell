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
        console.warn("BATTERY_HISTORY_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("BATTERY_HISTORY_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    function test_pushSampleAppendsAndTrims() {
        const h1 = BatteryHistory.pushSample([], { t: 1, percent: 80 }, 3);
        root.compare(h1, [{ t: 1, percent: 80 }]);

        const h2 = BatteryHistory.pushSample(
            [{ t: 1, percent: 80 }, { t: 2, percent: 81 }, { t: 3, percent: 82 }],
            { t: 4, percent: 83 }, 3
        );
        root.compare(h2, [{ t: 2, percent: 81 }, { t: 3, percent: 82 }, { t: 4, percent: 83 }]);
    }

    function test_availableFalseWithoutRealBattery() {
        // This machine is a desktop with no battery (verified during
        // planning) — UPower.displayDevice.isPresent/isLaptopBattery
        // should make `available` false, and `samples` must stay empty
        // rather than accumulating a fake reading.
        root.verify(!BatteryHistory.available, "expected no battery on this test host");
        root.compare(BatteryHistory.samples, []);
    }

    Component.onCompleted: {
        try {
            root.test_pushSampleAppendsAndTrims();
            root.test_availableFalseWithoutRealBattery();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
