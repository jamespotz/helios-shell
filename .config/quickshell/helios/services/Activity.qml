pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../services"

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
    property bool persistenceDirty: false
    property string persistedDayKey: ""
    property bool usageReady: false

    // App class (lowercased) -> nicer icon/label/category than the raw wm
    // class. Unlisted apps fall back to _prettify()'d class name, a generic
    // icon, and the "Other" category.
    readonly property var appMeta: ({
        "firefox": { icon: "public", label: "Firefox", category: "Browsing" },
        "librewolf": { icon: "public", label: "LibreWolf", category: "Browsing" },
        "chromium": { icon: "public", label: "Chromium", category: "Browsing" },
        "google-chrome": { icon: "public", label: "Chrome", category: "Browsing" },
        "app.zen_browser.zen": { icon: "public", label: "Zen Browser", category: "Browsing" },
        "org.telegram.desktop": { icon: "send", label: "Telegram", category: "Communication" },
        "discord": { icon: "forum", label: "Discord", category: "Communication" },
        "vesktop": { icon: "forum", label: "Vesktop", category: "Communication" },
        "code": { icon: "code", label: "VS Code", category: "Development" },
        "code-oss": { icon: "code", label: "VS Code", category: "Development" },
        "com.mitchellh.ghostty": { icon: "terminal", label: "Ghostty", category: "Development" },
        "kitty": { icon: "terminal", label: "Kitty", category: "Development" },
        "foot": { icon: "terminal", label: "Foot", category: "Development" },
        "org.kde.dolphin": { icon: "folder", label: "Dolphin", category: "Productivity" },
        "nautilus": { icon: "folder", label: "Files", category: "Productivity" },
        "org.gnome.nautilus": { icon: "folder", label: "Files", category: "Productivity" },
        "spotify": { icon: "music_note", label: "Spotify", category: "Media" },
        "onlyoffice-desktopeditors": { icon: "description", label: "ONLYOFFICE", category: "Productivity" },
        "obs": { icon: "videocam", label: "OBS Studio", category: "Media" },
        "steam": { icon: "sports_esports", label: "Steam", category: "Gaming" }
    })

    // Category -> theme color. Reuses the shell's existing semantic role
    // palette (see Colors.qml) instead of introducing category-specific
    // hardcoded colors, per AGENTS.md.
    readonly property var categoryColors: ({
        "Development": Colors.primary,
        "Communication": Colors.accent,
        "Browsing": Colors.success,
        "Media": Colors.secondary,
        "Productivity": Colors.tertiary,
        "Gaming": Colors.danger,
        "Other": Colors.subtext
    })
    function categoryColorFor(category) {
        return root.categoryColors[category] || Colors.subtext;
    }

    function _prettify(cls) {
        if (!cls) return "Unknown";
        const seg = cls.split(".").pop();
        return seg.length > 0 ? seg.charAt(0).toUpperCase() + seg.slice(1) : cls;
    }
    function _metaFor(cls) {
        return root.appMeta[(cls || "").toLowerCase()] || { icon: "apps", label: root._prettify(cls), category: "Other" };
    }

    function _dayKey(ms) {
        const d = new Date(ms);
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    // Credits elapsed time since the last tick/switch to whatever was
    // focused, then resets the clock — called both periodically and on every
    // focus change so a day-boundary crossing is off by at most one tick
    // interval instead of misattributing a whole session to the wrong day.
    // No-ops while idle (see idleMonitor below) — a focused-but-unattended
    // window shouldn't keep racking up "usage".
    function _tick() {
        if (!root.usageReady) {
            root.currentSince = Date.now();
            return false;
        }
        if (idleMonitor.isIdle) return false;
        const now = Date.now();
        let changed = false;
        if (root.currentApp && root.currentSince > 0) {
            const elapsed = (now - root.currentSince) / 1000;
            if (elapsed > 0) {
                const key = root._dayKey(now);
                const day = Object.assign({}, root.days[key]);
                day[root.currentApp] = (day[root.currentApp] || 0) + elapsed;
                root.days = Object.assign({}, root.days, { [key]: day });
                root.persistenceDirty = true;
                changed = true;
            }
        }
        root.currentSince = now;
        return changed;
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
        root.persistenceDirty = false;
    }

    // --- Derived data consumed by ActivityTab.qml -----------------------

    // Public, date-parameterized versions of the "today" derivations below
    // — ActivityTab's day nav calls these directly so paging to a past day
    // (within the 40-day retention window) shows that day's real numbers
    // instead of just relabeling the header.
    function totalSecondsFor(dayKey) { return root._totalFor(dayKey); }
    function fmtDuration(totalSeconds) { return root._fmtDuration(totalSeconds); }
    function appsFor(dayKey) {
        const day = root.days[dayKey] || {};
        const total = root._totalFor(dayKey);
        const list = Object.keys(day).map(cls => {
            const meta = root._metaFor(cls);
            return {
                cls: cls,
                name: meta.label,
                icon: meta.icon,
                category: meta.category,
                duration: root._fmtDuration(day[cls]),
                fraction: total > 0 ? day[cls] / total : 0,
                seconds: day[cls]
            };
        });
        list.sort((a, b) => b.seconds - a.seconds);
        return list;
    }
    function dayKeyFor(date) { return root._dayKey(date.getTime()); }

    // Per-app minutes across the current week (Mon..Sun) — drives the
    // sparkline in ActivityTab's expanded app row.
    function appSparkline(cls) {
        return root.weekDates.map(d => {
            const day = root.days[root._dayKey(d.getTime())];
            return Math.round(((day && day[cls]) || 0) / 60);
        });
    }

    // --- Per-app daily limits (display/save only — no enforcement) ------

    property var limits: ({}) // { "firefox": 30, ... } minutes/day

    function limitMinutesFor(cls) { return root.limits[cls] || 0; }
    function setLimitMinutes(cls, minutes) {
        root.limits = Object.assign({}, root.limits, { [cls]: minutes });
        limitsFile.setText(JSON.stringify(root.limits));
    }

    property FileView limitsFile: FileView {
        path: Quickshell.statePath("app-usage-limits.json")
        printErrors: false
        atomicWrites: true
        preload: true
        onLoaded: {
            try {
                const parsed = JSON.parse(limitsFile.text());
                if (parsed && typeof parsed === "object") root.limits = parsed;
            } catch (e) {
                // First run / empty file — start with no limits set.
            }
        }
    }

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

    // Read by every wall-clock-derived property below purely to create a
    // binding dependency — QML doesn't re-evaluate a binding just because
    // `new Date()` returns something different, so without this the
    // day/week/month derivations would freeze at whatever they evaluated to
    // when the shell started and go stale across a day/week boundary.
    property int _clockTick: 0
    property Timer clockTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root._clockTick++;
            const dayKey = root._dayKey(Date.now());
            if (root.persistedDayKey !== "" && root.persistedDayKey !== dayKey && root.persistenceDirty)
                root._save();
            root.persistedDayKey = dayKey;
        }
    }

    readonly property var weekDates: {
        root._clockTick;
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

    readonly property int highlightedDayIndex: { root._clockTick; return (new Date().getDay() + 6) % 7; }

    readonly property real todayTotalSeconds: root._totalFor(root._dayKey(Date.now()))
    readonly property string todayTotalText: root._fmtDuration(root.todayTotalSeconds)

    readonly property real dailyAverageSeconds:
        root.weekDates.reduce((acc, d) => acc + root._totalFor(root._dayKey(d.getTime())), 0) / 7
    readonly property string dailyAverageText: root._fmtDuration(root.dailyAverageSeconds)
    readonly property string dailyAverageRange:
        Qt.formatDate(root.weekDates[0], "MMM d") + " - " + Qt.formatDate(root.weekDates[6], "MMM d")

    readonly property bool deltaIsDown: root.todayTotalSeconds < root.dailyAverageSeconds
    readonly property string deltaText: root._fmtDuration(Math.abs(root.todayTotalSeconds - root.dailyAverageSeconds))

    readonly property var apps: root.appsFor(root._dayKey(Date.now()))

    readonly property string monthLabel: { root._clockTick; return Qt.formatDate(new Date(), "MMMM"); }
    readonly property int todayDay: { root._clockTick; return new Date().getDate(); }

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
        root._clockTick;
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
        onLoaded: {
            try {
                const parsed = JSON.parse(logFile.text());
                if (parsed && typeof parsed === "object") root.days = parsed;
            } catch (e) {
                // First run / empty file — start with an empty log.
            }
            root.usageReady = true;
            root.currentSince = Date.now();
        }
        onLoadFailed: {
            root.usageReady = true;
            root.currentSince = Date.now();
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
        onTriggered: root._tick()
    }

    property Timer persistenceTimer: Timer {
        interval: 3 * 60 * 1000
        running: true
        repeat: true
        onTriggered: { if (root.persistenceDirty) root._save(); }
    }

    // Native AFK detection via the real ext-idle-notify-v1 Wayland protocol
    // (no ActivityWatch-style external daemon needed) — respectInhibitors
    // means an active idle inhibitor (e.g. a video playing fullscreen) is
    // still treated as "active" rather than idle, which matches what a user
    // would consider real usage.
    property IdleMonitor idleMonitor: IdleMonitor {
        enabled: true
        timeout: 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle) {
                // _tick() itself now refuses to run once isIdle flips true,
                // so credit time up to the moment the user actually went
                // idle (now minus this monitor's own timeout window) here —
                // not the idle gap itself.
                const cutoff = Date.now() - timeout * 1000;
                if (root.currentApp && root.currentSince > 0 && cutoff > root.currentSince) {
                    const key = root._dayKey(cutoff);
                    const day = Object.assign({}, root.days[key]);
                    day[root.currentApp] = (day[root.currentApp] || 0) + (cutoff - root.currentSince) / 1000;
                    root.days = Object.assign({}, root.days, { [key]: day });
                    root.persistenceDirty = true;
                    root._save();
                }
            } else {
                // Resume the clock from now — the idle gap isn't attributed
                // to whatever was focused when the user stepped away.
                root.currentSince = Date.now();
            }
        }
    }

    Component.onCompleted: {
        root.persistedDayKey = root._dayKey(Date.now());
        root._onFocusChanged();
    }
    Component.onDestruction: {
        root._tick();
        if (root.persistenceDirty) root._save();
    }
}
