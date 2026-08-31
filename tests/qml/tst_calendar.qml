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
        console.warn("CALENDAR_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("CALENDAR_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    function test_eventsByDateGroupsAndPreservesOrder() {
        const events = [
            { summary: "Standup", date: "2026-09-01", allDay: false, startTime: "09:00", endTime: "09:15", source: "Personal" },
            { summary: "Dentist", date: "2026-09-02", allDay: false, startTime: "14:00", endTime: "15:00", source: "Personal" },
            { summary: "Team sync", date: "2026-09-01", allDay: false, startTime: "13:00", endTime: "13:30", source: "Personal" }
        ];
        const grouped = Calendar.eventsByDate(events);
        root.compare(Object.keys(grouped).sort(), ["2026-09-01", "2026-09-02"]);
        root.compare(grouped["2026-09-01"].length, 2);
        root.compare(grouped["2026-09-01"][0].summary, "Standup");
        root.compare(grouped["2026-09-01"][1].summary, "Team sync");
        root.compare(grouped["2026-09-02"][0].summary, "Dentist");
    }

    function test_eventsByDateHandlesEmptyInput() {
        root.compare(Calendar.eventsByDate([]), {});
        root.compare(Calendar.eventsByDate(null), {});
    }

    Component.onCompleted: {
        try {
            root.test_eventsByDateGroupsAndPreservesOrder();
            root.test_eventsByDateHandlesEmptyInput();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
