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
    property var events: []
    property var subscriptions: []
    property var subscriptionErrors: []
    property bool ready: false
    property bool refreshing: false

    signal persistenceRequested(var subscriptions)
    signal refreshRequested()

    readonly property var state: ({
        ready: root.ready,
        refreshing: root.refreshing,
        events: root.events,
        eventsByDate: root._eventsByDate(root.events),
        subscriptions: root.subscriptions.map(subscription => ({
            id: subscription.id,
            label: subscription.label,
            url: subscription.url,
            enabled: subscription.enabled !== false,
            error: root.subscriptionErrors.find(error => error.id === subscription.id) || null
        }))
    })

    readonly property string cacheDir: Quickshell.env("HOME") + "/.cache/helios"
    readonly property string subscriptionsPath: root.cacheDir + "/calendar-subscriptions.json"
    readonly property string eventsPath: root.cacheDir + "/calendar-events.json"
    readonly property int refreshInterval: 5 * 60 * 1000
    property double lastRefreshAt: 0

    function subscribe(label, url) {
        const cleanLabel = String(label || "").trim();
        const cleanUrl = String(url || "").trim();
        if (!cleanLabel || !cleanUrl) return false;
        const taken = new Set(root.subscriptions.map(subscription => subscription.id));
        let id;
        do id = "sub-" + Math.random().toString(36).slice(2, 10); while (taken.has(id));
        root.subscriptions = root.subscriptions.concat([{ id: id, label: cleanLabel, url: cleanUrl }]);
        root.persistenceRequested(root.subscriptions);
        root.refreshRequested();
        return true;
    }

    function unsubscribe(id) {
        if (!root.subscriptions.some(subscription => subscription.id === id)) return false;
        root.subscriptions = root.subscriptions.filter(subscription => subscription.id !== id);
        root.persistenceRequested(root.subscriptions);
        root.refreshRequested();
        return true;
    }

    function setSubscriptionEnabled(id, enabled) {
        if (!root.subscriptions.some(subscription => subscription.id === id)) return false;
        root.subscriptions = root.subscriptions.map(subscription =>
            subscription.id === id ? Object.assign({}, subscription, { enabled: enabled }) : subscription);
        root.persistenceRequested(root.subscriptions);
        root.refreshRequested();
        return true;
    }

    function _eventsByDate(list) {
        const grouped = {};
        for (const event of (list || [])) {
            if (!grouped[event.date]) grouped[event.date] = [];
            grouped[event.date].push(event);
        }
        return grouped;
    }

    function _cachedRefreshTime(cached) {
        if (!cached || !cached.result || !Array.isArray(cached.result.events)) return 0;
        const result = cached.result;
        if (result.events.length === 0 && result.fetchSucceeded !== true) return 0;
        return Number(cached.savedAt) || 0;
    }

    function _beginRefresh() { root.refreshing = true; }
    function _cancelRefresh() { root.refreshing = false; }
    function _completeRefresh(result) {
        const next = result || {};
        root.events = next.events || [];
        root.subscriptionErrors = next.subscriptionErrors || [];
        root.ready = true;
        root.refreshing = false;
    }

    // ─── Upcoming-meeting alert ─────────────────────────────────────────
    // Surfaces one timed event at a time, starting 5 minutes before it
    // begins, for the Island to auto-peek (see Bar.qml's meetingMode,
    // modeled on notifyMode/taskMode) independent of whether the Calendar
    // tab is open — this timer always runs, unlike refreshTimer above.
    property var upcomingAlert: null
    property var _alertedKeys: ({})

    // event.date is "YYYY-MM-DD", event.startTime is "HH:MM" (both from
    // calendar-info.py) — parsed as local time, matching how the agenda
    // already displays them.
    function _eventStart(event) {
        if (!event.startTime) return null;
        const [y, m, d] = event.date.split("-").map(Number);
        const [hh, mm] = event.startTime.split(":").map(Number);
        return new Date(y, m - 1, d, hh, mm);
    }

    function _eventKey(event) { return event.date + "|" + event.startTime + "|" + event.summary; }

    function dismissAlert() { root.upcomingAlert = null; }

    function _scanForAlerts() {
        if (root.upcomingAlert) return;
        const now = Date.now();
        for (const event of root.state.events) {
            const start = root._eventStart(event);
            if (!start) continue;
            const key = root._eventKey(event);
            if (root._alertedKeys[key]) continue;
            const minutesUntil = (start.getTime() - now) / 60000;
            // [-1, 5]: fires once, 5 minutes ahead of start, and stays valid
            // for a minute after in case the 20s scan interval just missed it.
            if (minutesUntil <= 5 && minutesUntil >= -1) {
                root._alertedKeys = Object.assign({}, root._alertedKeys, { [key]: true });
                root.upcomingAlert = event;
                if (root.meetingFocusId) {
                    const preset = FocusModes.presets.find(p => p.id === root.meetingFocusId);
                    if (preset) FocusModes.apply(preset);
                }
                break;
            }
        }
    }

    property Timer alertTimer: Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._scanForAlerts()
    }

    // Which Focus preset (if any) to auto-apply when a meeting alert
    // fires — "" means off. Persisted separately from subscriptions since
    // it's an unrelated setting that happens to live on the same service.
    property string meetingFocusId: ""

    function setMeetingFocusId(id) {
        root.meetingFocusId = id;
        meetingFocusFile.setText(id);
    }

    property FileView meetingFocusFile: FileView {
        path: root.cacheDir + "/calendar-meeting-focus.txt"
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: root.meetingFocusId = meetingFocusFile.text().trim()
    }

    function setActive(active) {
        if (root._active === active) return;
        root._active = active;
        if (active && (!root.state.ready || Date.now() - root.lastRefreshAt >= root.refreshInterval))
            root.refresh();
    }

    function refresh() {
        root._beginRefresh();
        proc.running = false;
        proc.running = true;
    }

    property Process proc: Process {
        command: ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/calendar-info.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed.fetchSucceeded === false && parsed.events.length === 0) {
                        root._cancelRefresh();
                        return;
                    }
                    root._completeRefresh(parsed);
                    root.lastRefreshAt = Date.now();
                    eventsFile.setText(JSON.stringify({ savedAt: root.lastRefreshAt, result: parsed }));
                } catch (e) {
                    console.warn("[Calendar] failed to parse calendar-info.py output:", e);
                    root._cancelRefresh();
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
                if (Array.isArray(parsed)) root.subscriptions = parsed;
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
                    root.lastRefreshAt = root._cachedRefreshTime(cached);
                    root._completeRefresh(cached.result);
                }
            } catch (e) {
                // First run / empty cache.
            }
        }
    }

    Component.onCompleted: root.ensureCacheDirProc.running = true

    onPersistenceRequested: subscriptions => subscriptionsFile.setText(JSON.stringify(subscriptions))
    onRefreshRequested: root.refresh()

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
