pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import Quickshell.Hyprland

QtObject {
    id: root

    // Single global NotificationServer — only one process may own the
    // org.freedesktop.Notifications DBus name, so this must stay a singleton
    // even though every screen's island reads `list` to render its own
    // notify-mode card. Newest first; NotifyCard groups when there's more
    // than one pending.
    property var list: []
    // Notification history — persists dismissed notifications so the user
    // can review missed ones. Capped at 50 entries.
    property var history: []
    readonly property int historyMax: 50

    // When DND is active, notifications still arrive and go to history but
    // don't appear in `list` (which drives the popup notify-mode in Bar.qml).
    readonly property bool dndActive: Bridge.dndEnabled

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            notification.closed.connect(() => root.remove(notification));
            // Always add to history regardless of DND state
            root.history = [{ summary: notification.summary, body: notification.body,
                appName: notification.appName, appIcon: notification.appIcon,
                time: new Date() }].concat(root.history).slice(0, root.historyMax);
            // Only show popup if DND is off
            if (!root.dndActive) {
                root.list = [notification].concat(root.list);
            }
        }
    }

    function remove(notification) {
        root.list = root.list.filter(n => n !== notification);
    }

    function dismiss(notification) {
        notification.dismiss();
    }

    function dismissAll() {
        for (const n of root.list) n.dismiss();
    }

    function clearHistory() {
        root.history = [];
    }

    // Raises and focuses the window of the app that sent a notification.
    // Also tries to invoke the notification's "default" action for deep-
    // linking (e.g., Slack thread navigation) before focusing the window.
    function focusApp(notification) {
        const needle = (notification.desktopEntry || notification.appName || "").toLowerCase();
        if (!needle) return false;
        for (const top of Hyprland.toplevels.values) {
            const appId = (top.wayland && top.wayland.appId || "").toLowerCase();
            if (appId && (appId === needle || appId.includes(needle) || needle.includes(appId))) {
                top.wayland.activate();
                return true;
            }
        }
        return false;
    }
}
