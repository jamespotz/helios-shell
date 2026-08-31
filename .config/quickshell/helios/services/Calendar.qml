pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Local calendar events via Evolution Data Server — the backend GNOME
// Calendar / GNOME Online Accounts already use on this system. One-shot
// Process + StdioCollector per refresh (the same pattern
// services/Bluetooth.qml's getObjectsProc uses) rather than a continuous
// polling loop — calendar data changes far less often than system stats.
QtObject {
    id: root

    property var events: [] // [{ summary, date, allDay, startTime, endTime, source }]
    property bool ready: false
    property bool active: false // panel visibility — gates the refresh timer

    function open() { root.active = true; root.refresh(); }
    function close() { root.active = false; }

    function refresh() {
        proc.running = false;
        proc.running = true;
    }

    // Pure — exported for direct testing (tests/qml/tst_calendar.qml).
    function eventsByDate(list) {
        const byDate = {};
        for (const e of (list || [])) {
            if (!byDate[e.date]) byDate[e.date] = [];
            byDate[e.date].push(e);
        }
        return byDate;
    }

    property Process proc: Process {
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/calendar-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.events = JSON.parse(text);
                } catch (e) {
                    console.warn("[Calendar] failed to parse calendar-info.py output:", e);
                    root.events = [];
                }
                root.ready = true;
            }
        }
    }

    // Refresh every 5 minutes while the tab is open — cheap (one local
    // D-Bus query, no network) and picks up events added elsewhere
    // (GNOME Calendar, a synced account) during the session.
    property Timer refreshTimer: Timer {
        interval: 5 * 60 * 1000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
}
