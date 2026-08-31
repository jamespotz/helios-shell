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

    function test_sanitizeSubscriptionTrimsAndValidates() {
        root.compare(Calendar.sanitizeSubscription("  Work  ", "  https://example.com/cal.ics  "), { label: "Work", url: "https://example.com/cal.ics" });
        root.compare(Calendar.sanitizeSubscription("", "https://example.com/cal.ics"), null);
        root.compare(Calendar.sanitizeSubscription("Work", ""), null);
        root.compare(Calendar.sanitizeSubscription("   ", "   "), null);
    }

    function test_generateSubscriptionIdAvoidsCollisionAndIsNonEmpty() {
        const existing = [{ id: "sub-fixed", label: "x", url: "y" }];
        const id = Calendar.generateSubscriptionId(existing);
        root.verify(id.length > 0, "generated id was empty");
        root.verify(id !== "sub-fixed", "generated id collided with an existing one");
        const id2 = Calendar.generateSubscriptionId(existing);
        root.verify(id !== id2, "two calls produced the same id");
    }

    Component.onCompleted: {
        try {
            root.test_eventsByDateGroupsAndPreservesOrder();
            root.test_eventsByDateHandlesEmptyInput();
            root.test_sanitizeSubscriptionTrimsAndValidates();
            root.test_generateSubscriptionIdAvoidsCollisionAndIsNonEmpty();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
