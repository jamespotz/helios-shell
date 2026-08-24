pragma Singleton
import QtQuick

// Mock time-tracking dataset for modules/bar/ActivityTab.qml, shaped like a
// future ActivityWatch (localhost:5600) query result — swapping this for a
// real query should only mean rewriting the property bindings below, not the
// UI that consumes them.
QtObject {
    id: root

    readonly property string dailyAverageText: "6h 19m"
    readonly property string dailyAverageRange: "May 11 - May 17"
    readonly property string todayTotalText: "6h 15m"
    readonly property string deltaText: "1h 31m"
    readonly property bool deltaIsDown: true

    readonly property var weekly: [
        { day: "Mon", minutes: 210 },
        { day: "Tue", minutes: 230 },
        { day: "Wed", minutes: 205 },
        { day: "Thu", minutes: 250 },
        { day: "Fri", minutes: 375 },
        { day: "Sat", minutes: 8 },
        { day: "Sun", minutes: 5 }
    ]
    readonly property int highlightedDayIndex: 4 // Fri

    readonly property var apps: [
        { name: "Firefox", icon: "public", duration: "3h 14m", fraction: 0.55 },
        { name: "kitty", icon: "terminal", duration: "1h 14m", fraction: 0.28 },
        { name: "Desktop", icon: "desktop_windows", duration: "58m", fraction: 0.20 },
        { name: "Telegram", icon: "send", duration: "41m", fraction: 0.12 },
        { name: "ONLYOFFICE", icon: "description", duration: "2m", fraction: 0.02 }
    ]

    readonly property string monthLabel: "May"
    readonly property int todayDay: 15

    // Deterministic mock heatmap intensity (0..3) per day-of-month — swap for
    // a real per-day total once wired to a backend.
    function levelFor(day) {
        if (day <= 0) return -1;
        return (day * 7 + 3) % 4;
    }

    readonly property var monthWeeks: {
        const year = 2026, month = 4; // May 2026, matches the mockup
        const startOffset = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < startOffset; i++) cells.push(0);
        for (let d = 1; d <= daysInMonth; d++) cells.push(d);
        while (cells.length % 7 !== 0) cells.push(0);
        const rows = [];
        for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
        return rows;
    }
}
