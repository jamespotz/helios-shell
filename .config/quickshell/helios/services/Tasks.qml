pragma Singleton
import QtQuick

// Tracks background activity the Island should surface without the user
// opening it — long-running shell commands, file transfers, anything a
// script wants to report progress on. Driven entirely over the "task" IPC
// target (see shell.qml) so any keybind or script can wrap a command with
// `task start`/`task progress`/`task done` the same way notifications
// arrive over DBus. Modeled on Notifications' popup list — see
// NotificationCore.qml — but simple enough not to need its own Core split.
QtObject {
    id: root

    // { id, label, progress (0-1, or -1 for indeterminate), status: "running" | "done" | "error" }
    property var items: []

    function start(id, label) {
        if (!id) return;
        const existing = root.items.find(t => t.id === id);
        const task = { id: id, label: label || id, progress: -1, status: "running" };
        root.items = existing
            ? root.items.map(t => t.id === id ? task : t)
            : root.items.concat([task]);
    }

    function progress(id, value, label) {
        const task = root.items.find(t => t.id === id);
        if (!task) return;
        root.items = root.items.map(t => t.id === id
            ? Object.assign({}, t, { progress: value, label: label || t.label })
            : t);
    }

    function finish(id, ok) {
        const task = root.items.find(t => t.id === id);
        if (!task) return;
        root.items = root.items.map(t => t.id === id ? Object.assign({}, t, { status: ok ? "done" : "error", progress: 1 }) : t);
    }

    // TaskCard.qml calls this once it's shown a finished task long enough
    // to read — same shape as Notifications.dismiss() being UI-driven.
    function remove(id) { root.items = root.items.filter(t => t.id !== id); }
}
