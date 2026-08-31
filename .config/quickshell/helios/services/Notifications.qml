pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

QtObject {
    id: root

    // ─── Public state ────────────────────────────────────────────────────
    // Live notification popups (newest first). NotifyCard reads this.
    property var list: []
    // Persistent history (newest first, capped). Survives dismiss.
    property var history: []
    readonly property int historyMax: 50

    // DND — notifications still arrive to history but skip the popup list.
    readonly property bool dndActive: Bridge.dndEnabled

    // ─── Notification server ─────────────────────────────────────────────
    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
            notification.closed.connect(() => root.remove(notification));

            root.history = [root._historyEntry(notification)]
                .concat(root.history)
                .slice(0, root.historyMax);

            if (!root.dndActive) {
                root.list = [notification].concat(root.list);
            }
        }
    }

    // ─── Public API ──────────────────────────────────────────────────────

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

    function _historyEntry(notification) {
        return {
            summary: notification.summary || "",
            body: notification.body || "",
            appName: notification.appName || "",
            appIcon: notification.appIcon || "",
            desktopEntry: notification.desktopEntry || "",
            time: new Date()
        };
    }

    // ── "Open" for a live popup (NotifyCard) ──
    // The freedesktop spec defines the "default" action (or an empty-string
    // identifier) as what fires when you click the notification body — this
    // is what Slack/Teams/etc. use to navigate to the exact channel/thread.
    // Some applications handle the action without raising their window, so
    // the matching Hyprland toplevel is focused immediately afterwards.
    function _findDefaultAction(notification) {
        if (!notification || !notification.actions) return null;
        return notification.actions.find(a => a.identifier === "default")
            || notification.actions.find(a => a.identifier === "")
            || null;
    }

    // Whether NotifyCard should show the Open icon for this live notification.
    // True for a registered default action or a desktop entry that may match
    // a running window.
    function hasDefaultAction(notification) {
        return !!root._findDefaultAction(notification)
            || !!(notification && notification.desktopEntry);
    }

    function focusApp(notification) {
        if (!notification) return false;

        const action = root._findDefaultAction(notification);
        // Copy the identifiers while the notification is alive. invoke() may
        // dismiss a non-resident notification and destroy its QML object.
        const desktopEntry = notification.desktopEntry || "";
        const appName = notification.appName || "";

        if (action) {
            action.invoke();

            if (desktopEntry || appName) {
                AppLaunch.focusWindow(desktopEntry, appName);
                AppLaunch.focusWithRetry(desktopEntry, appName, 3);
            }

            return true;
        }

        return AppLaunch.focusWindow(desktopEntry, appName);
    }

    // ── "Open" for a history entry (NotificationHistoryTab) ──
    // History entries have no live DBus object left to invoke an action on,
    // just the identifiers captured in _historyEntry(). AppLaunch focuses a
    // matching window or relaunches through the desktop entry.
    function openApp(entry) {
        if (!entry) return false;
        return AppLaunch.focusOrLaunch(entry.desktopEntry, entry.appName);
    }
}
