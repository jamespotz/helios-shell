pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Real per-app focus-time tracking for modules/bar/ActivityTab.qml.
//
// ActivityWatch was the obvious off-the-shelf choice, but its window watcher
// (aw-watcher-window) only implements Linux window detection via raw Xlib —
// there's no Wayland path in it at all — so on a native-Wayland Hyprland
// session it can only ever see XWayland-mapped windows and reports "unknown"
// for everything else. Instead this taps the same Hyprland.activeToplevel
// stream the rest of this shell already consumes (see ActiveWindow.qml) and
// accumulates focused-seconds per app class into a small local JSON log.
//
// Known limitation: this measures raw focus duration, not idle-aware
// "active" time like ActivityWatch (no AFK detection) — a window left
// focused and unattended still counts as focused time.
QtObject {
    id: root

    property var days: ({}) // { "2026-08-24": { "firefox": 1234.5, ... }, ... }
    property string currentApp: ""
    property real currentSince: 0 // Date.now() ms

    // App class (lowercased) -> nicer icon/label than the raw wm class.
    // Unlisted apps fall back to _prettify()'d class name + a generic icon.
    readonly property var appMeta: ({
        "firefox": { icon: "public", label: "Firefox" },
        "librewolf": { icon: "public", label: "LibreWolf" },
        "chromium": { icon: "public", label: "Chromium" },
        "google-chrome": { icon: "public", label: "Chrome" },
        "app.zen_browser.zen": { icon: "public", label: "Zen Browser" },
        "org.telegram.desktop": { icon: "send", label: "Telegram" },
        "discord": { icon: "forum", label: "Discord" },
        "vesktop": { icon: "forum", label: "Vesktop" },
        "code": { icon: "code", label: "VS Code" },
        "code-oss": { icon: "code", label: "VS Code" },
        "com.mitchellh.ghostty": { icon: "terminal", label: "Ghostty" },
        "kitty": { icon: "terminal", label: "Kitty" },
        "foot": { icon: "terminal", label: "Foot" },
        "org.kde.dolphin": { icon: "folder", label: "Dolphin" },
        "nautilus": { icon: "folder", label: "Files" },
        "org.gnome.nautilus": { icon: "folder", label: "Files" },
        "spotify": { icon: "music_note", label: "Spotify" },
        "onlyoffice-desktopeditors": { icon: "description", label: "ONLYOFFICE" },
        "obs": { icon: "videocam", label: "OBS Studio" },
        "steam": { icon: "sports_esports", label: "Steam" }
    })

    function _prettify(cls) {
        if (!cls) return "Unknown";
        const seg = cls.split(".").pop();
        return seg.length > 0 ? seg.charAt(0).toUpperCase() + seg.slice(1) : cls;
    }
    function _metaFor(cls) {
        return root.appMeta[(cls || "").toLowerCase()] || { icon: "apps", label: root._prettify(cls) };
    }

    function _dayKey(ms) {
        const d = new Date(ms);
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    // Credits elapsed time since the last tick/switch to whatever was
    // focused, then resets the clock — called both periodically and on every
    // focus change so a day-boundary crossing is off by at most one tick
    // interval instead of misattributing a whole session to the wrong day.
    function _tick() {
        const now = Date.now();
        if (root.currentApp && root.currentSince > 0) {
            const elapsed = (now - root.currentSince) / 1000;
            if (elapsed > 0) {
                const key = root._dayKey(now);
                const day = Object.assign({}, root.days[key]);
                day[root.currentApp] = (day[root.currentApp] || 0) + elapsed;
                root.days = Object.assign({}, root.days, { [key]: day });
            }
        }
        root.currentSince = now;
    }

    function _onFocusChanged() {
        root._tick();
        const top = Hyprland.activeToplevel;
        const ipc = top ? top.lastIpcObject : null;
        root.currentApp = ipc ? (ipc.class || ipc.initialClass || "") : "";
    }

    function _prune() {
        const cutoff = new Date();
        cutoff.setDate(cutoff.getDate() - 40);
        const keep = {};
        for (const key in root.days) {
            const parts = key.split("-").map(n => parseInt(n, 10));
            const d = new Date(parts[0], parts[1] - 1, parts[2]);
            if (d >= cutoff) keep[key] = root.days[key];
        }
        root.days = keep;
    }

    function _save() {
        root._prune();
        logFile.setText(JSON.stringify(root.days));
    }

    // --- Derived data consumed by ActivityTab.qml -----------------------

    function _totalFor(dayKey) {
        const day = root.days[dayKey];
        if (!day) return 0;
        let sum = 0;
        for (const app in day) sum += day[app];
        return sum;
    }

    function _fmtDuration(totalSeconds) {
        const totalMinutes = Math.round(totalSeconds / 60);
        const h = Math.floor(totalMinutes / 60);
        const m = totalMinutes % 60;
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property var weekDates: {
        const now = new Date();
        const monday = new Date(now);
        monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
        monday.setHours(0, 0, 0, 0);
        const out = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(monday);
            d.setDate(monday.getDate() + i);
            out.push(d);
        }
        return out;
    }

    readonly property var weekly: root.weekDates.map(d => ({
        day: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][(d.getDay() + 6) % 7],
        minutes: Math.round(root._totalFor(root._dayKey(d.getTime())) / 60)
    }))

    readonly property int highlightedDayIndex: (new Date().getDay() + 6) % 7

    readonly property real todayTotalSeconds: root._totalFor(root._dayKey(Date.now()))
    readonly property string todayTotalText: root._fmtDuration(root.todayTotalSeconds)

    readonly property real dailyAverageSeconds:
        root.weekDates.reduce((acc, d) => acc + root._totalFor(root._dayKey(d.getTime())), 0) / 7
    readonly property string dailyAverageText: root._fmtDuration(root.dailyAverageSeconds)
    readonly property string dailyAverageRange:
        Qt.formatDate(root.weekDates[0], "MMM d") + " - " + Qt.formatDate(root.weekDates[6], "MMM d")

    readonly property bool deltaIsDown: root.todayTotalSeconds < root.dailyAverageSeconds
    readonly property string deltaText: root._fmtDuration(Math.abs(root.todayTotalSeconds - root.dailyAverageSeconds))

    readonly property var apps: {
        const day = root.days[root._dayKey(Date.now())] || {};
        const total = root.todayTotalSeconds;
        const list = Object.keys(day).map(cls => {
            const meta = root._metaFor(cls);
            return {
                name: meta.label,
                icon: meta.icon,
                duration: root._fmtDuration(day[cls]),
                fraction: total > 0 ? day[cls] / total : 0,
                seconds: day[cls]
            };
        });
        list.sort((a, b) => b.seconds - a.seconds);
        return list;
    }

    readonly property string monthLabel: Qt.formatDate(new Date(), "MMMM")
    readonly property int todayDay: new Date().getDate()

    // Real intensity level (0-3) from actual tracked hours that day. Days
    // that haven't happened yet (or aren't part of this month) render blank.
    function levelFor(day) {
        if (day <= 0 || day > root.todayDay) return -1;
        const now = new Date();
        const key = now.getFullYear() + "-" + String(now.getMonth() + 1).padStart(2, "0") + "-" + String(day).padStart(2, "0");
        const hours = root._totalFor(key) / 3600;
        if (hours <= 0) return 0;
        if (hours < 2) return 1;
        if (hours < 5) return 2;
        return 3;
    }

    readonly property var monthWeeks: {
        const now = new Date();
        const year = now.getFullYear(), month = now.getMonth();
        const startOffset = (new Date(year, month, 1).getDay() + 6) % 7; // Monday-first
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < startOffset; i++) cells.push(0);
        for (let d = 1; d <= daysInMonth; d++) cells.push(d);
        while (cells.length % 7 !== 0) cells.push(0);
        const rows = [];
        for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
        return rows;
    }

    property FileView logFile: FileView {
        path: Quickshell.statePath("app-usage.json")
        printErrors: false
        atomicWrites: true
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(logFile.text());
                if (parsed && typeof parsed === "object") root.days = parsed;
            } catch (e) {
                // First run / empty file — start with an empty log.
            }
        }
    }

    property Connections focusWatcher: Connections {
        target: Hyprland
        function onActiveToplevelChanged() { root._onFocusChanged() }
    }

    property Timer tickTimer: Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: { root._tick(); root._save(); }
    }

    Component.onCompleted: root._onFocusChanged()
}
