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

    property bool _active: false
    readonly property CalendarCore _core: CalendarCore {
        onPersistenceRequested: subscriptions => subscriptionsFile.setText(JSON.stringify(subscriptions))
        onRefreshRequested: root.refresh()
    }
    readonly property var state: root._core.state

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/helios"
    readonly property string subscriptionsPath: root.cacheDir + "/calendar-subscriptions.json"
    readonly property string eventsPath: root.cacheDir + "/calendar-events.json"
    readonly property int refreshInterval: 5 * 60 * 1000
    property double lastRefreshAt: 0

    function subscribe(label, url) { return root._core.subscribe(label, url); }
    function unsubscribe(id) { return root._core.unsubscribe(id); }

    function setActive(active) {
        if (root._active === active) return;
        root._active = active;
        if (active && (!root.state.ready || Date.now() - root.lastRefreshAt >= root.refreshInterval))
            root.refresh();
    }

    function refresh() {
        root._core.beginRefresh();
        proc.running = false;
        proc.running = true;
    }

    property Process proc: Process {
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/calendar-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root._core.completeRefresh(parsed);
                    root.lastRefreshAt = Date.now();
                    eventsFile.setText(JSON.stringify({ savedAt: root.lastRefreshAt, result: parsed }));
                } catch (e) {
                    console.warn("[Calendar] failed to parse calendar-info.py output:", e);
                    root._core.cancelRefresh();
                }
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
        onLoaded: {
            try {
                const parsed = JSON.parse(subscriptionsFile.text());
                if (Array.isArray(parsed)) root._core.subscriptions = parsed;
            } catch (e) {
                // First run / empty file.
            }
        }
    }

    property FileView eventsFile: FileView {
        path: root.eventsPath
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const cached = JSON.parse(eventsFile.text());
                if (cached && cached.result && Array.isArray(cached.result.events)) {
                    root.lastRefreshAt = Number(cached.savedAt) || 0;
                    root._core.completeRefresh(cached.result);
                }
            } catch (e) {
                // First run / empty cache.
            }
        }
    }

    Component.onCompleted: root.ensureCacheDirProc.running = true

    // Refresh every 5 minutes while the tab is open — cheap (one local
    // D-Bus query, no network) and picks up events added elsewhere
    // (GNOME Calendar, a synced account) during the session.
    property Timer refreshTimer: Timer {
        interval: root.refreshInterval
        running: root._active
        repeat: true
        onTriggered: root.refresh()
    }
}
