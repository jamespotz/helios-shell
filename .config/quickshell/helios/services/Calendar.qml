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

    property var subscriptions: [] // [{ id, label, url }]
    property var subscriptionErrors: [] // [{ id, label, message }]

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/helios"
    readonly property string subscriptionsPath: root.cacheDir + "/calendar-subscriptions.json"

    // Pure — exported for direct testing (tests/qml/tst_calendar.qml).
    function sanitizeSubscription(label, url) {
        const trimmedLabel = (label || "").trim();
        const trimmedUrl = (url || "").trim();
        if (!trimmedLabel || !trimmedUrl) return null;
        return { label: trimmedLabel, url: trimmedUrl };
    }

    function generateSubscriptionId(existing) {
        const taken = new Set((existing || []).map(s => s.id));
        let id;
        do {
            id = "sub-" + Math.random().toString(36).slice(2, 10);
        } while (taken.has(id));
        return id;
    }

    function addSubscription(label, url) {
        const clean = root.sanitizeSubscription(label, url);
        if (!clean) return;
        const id = root.generateSubscriptionId(root.subscriptions);
        root.subscriptions = root.subscriptions.concat([{ id: id, label: clean.label, url: clean.url }]);
        root._saveSubscriptions();
        root.refresh();
    }

    function removeSubscription(id) {
        root.subscriptions = root.subscriptions.filter(s => s.id !== id);
        root._saveSubscriptions();
        root.refresh();
    }

    function _saveSubscriptions() {
        subscriptionsFile.setText(JSON.stringify(root.subscriptions));
    }

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
                    const parsed = JSON.parse(text);
                    root.events = parsed.events || [];
                    root.subscriptionErrors = parsed.subscriptionErrors || [];
                } catch (e) {
                    console.warn("[Calendar] failed to parse calendar-info.py output:", e);
                    root.events = [];
                    root.subscriptionErrors = [];
                }
                root.ready = true;
            }
        }
    }

    // ~/.cache/helios/ isn't guaranteed to exist before this runs — matches
    // services/Cava.qml's own `mkdir -p` before it writes into the same
    // directory for its cava.conf.
    property Process ensureCacheDirProc: Process {
        command: ["mkdir", "-p", root.cacheDir]
    }

    property FileView subscriptionsFile: FileView {
        path: root.subscriptionsPath
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(subscriptionsFile.text());
                if (Array.isArray(parsed)) root.subscriptions = parsed;
            } catch (e) {
                // First run / empty file.
            }
        }
    }

    Component.onCompleted: root.ensureCacheDirProc.running = true

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
