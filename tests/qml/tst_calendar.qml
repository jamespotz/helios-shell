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

    property int persistenceRequests: 0
    property int refreshRequests: 0
    CalendarCore {
        id: calendar
        onPersistenceRequested: root.persistenceRequests++
        onRefreshRequested: root.refreshRequests++
    }

    function test_eventsByDateGroupsAndPreservesOrder() {
        const events = [
            { summary: "Standup", date: "2026-09-01", allDay: false, startTime: "09:00", endTime: "09:15", source: "Personal" },
            { summary: "Dentist", date: "2026-09-02", allDay: false, startTime: "14:00", endTime: "15:00", source: "Personal" },
            { summary: "Team sync", date: "2026-09-01", allDay: false, startTime: "13:00", endTime: "13:30", source: "Personal" }
        ];
        calendar.completeRefresh({ events: events, subscriptionErrors: [] });
        const grouped = calendar.state.eventsByDate;
        root.compare(Object.keys(grouped).sort(), ["2026-09-01", "2026-09-02"]);
        root.compare(grouped["2026-09-01"].length, 2);
        root.compare(grouped["2026-09-01"][0].summary, "Standup");
        root.compare(grouped["2026-09-01"][1].summary, "Team sync");
        root.compare(grouped["2026-09-02"][0].summary, "Dentist");
    }

    function test_eventsByDateHandlesEmptyInput() {
        calendar.completeRefresh({ events: [], subscriptionErrors: [] });
        root.compare(calendar.state.eventsByDate, {});
    }

    function test_sanitizeSubscriptionTrimsAndValidates() {
        calendar.subscriptions = [];
        root.persistenceRequests = 0;
        root.refreshRequests = 0;
        root.verify(calendar.subscribe("  Work  ", "  https://example.com/cal.ics  "));
        root.compare(calendar.state.subscriptions[0].label, "Work");
        root.compare(calendar.state.subscriptions[0].url, "https://example.com/cal.ics");
        root.compare(root.persistenceRequests, 1);
        root.compare(root.refreshRequests, 1);
        root.verify(!calendar.subscribe("", "https://example.com/cal.ics"));
        root.verify(!calendar.subscribe("Work", ""));
    }

    function test_generateSubscriptionIdAvoidsCollisionAndIsNonEmpty() {
        const id = calendar.state.subscriptions[0].id;
        root.verify(id.length > 0, "generated id was empty");
        root.verify(calendar.unsubscribe(id));
        root.compare(calendar.state.subscriptions.length, 0);
        root.verify(!calendar.unsubscribe("missing"));
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
