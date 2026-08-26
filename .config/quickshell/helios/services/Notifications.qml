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

            root.history = [{
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                appIcon: notification.appIcon || "",
                desktopEntry: notification.desktopEntry || "",
                time: new Date()
            }].concat(root.history).slice(0, root.historyMax);

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

    // ── "Open" for a live popup (NotifyCard) ──
    // The freedesktop spec defines the "default" action (or an empty-string
    // identifier) as what fires when you click the notification body — this
    // is what Slack/Teams/etc. use to navigate to the exact channel/thread.
    // We only ever invoke that one action; apps that don't register one
    // simply have no "Open" behavior, same as clicking a DankMaterialShell
    // notification popup.
    function _findDefaultAction(notification) {
        if (!notification || !notification.actions) return null;
        return notification.actions.find(a => a.identifier === "default")
            || notification.actions.find(a => a.identifier === "")
            || null;
    }

    // Whether NotifyCard should show the Open icon for this live notification.
    function hasDefaultAction(notification) {
        return !!root._findDefaultAction(notification);
    }

    function focusApp(notification) {
        const action = root._findDefaultAction(notification);
        if (!action) return false;
        action.invoke();
        return true;
    }

    // ── "Open" for a history entry (NotificationHistoryTab) ──
    // History entries have no live DBus object left to invoke an action on,
    // so this just relaunches the app via its .desktop entry — most apps are
    // single-instance and focus their existing window themselves on relaunch.
    //
    // heuristicLookup("") does NOT return null — it returns some arbitrary
    // entry (seen returning org.gnome.Maps / org.gnome.DiskUtility) — so
    // apps like notify-send that send no desktop-entry hint must never reach
    // it with an empty string, or "Open" launches a random unrelated app.
    function _resolveEntry(entry) {
        if (!entry) return null;
        const desktop = entry.desktopEntry || "";
        const appName = entry.appName || "";
        const target = (desktop && DesktopEntries.heuristicLookup(desktop))
            || (appName && DesktopEntries.heuristicLookup(appName));
        return (target && !target.noDisplay) ? target : null;
    }

    // Whether NotificationHistoryTab should show the Open icon for this entry.
    function canOpenApp(entry) {
        return !!root._resolveEntry(entry);
    }

    function openApp(entry) {
        const target = root._resolveEntry(entry);
        if (!target) return false;
        root._launchEntry(target);
        return true;
    }

    // Launch helper — same logic as Launcher.qml's launchApp() to handle
    // terminal apps correctly.
    function _launchEntry(entry) {
        if (entry.runInTerminal) {
            const cmd = entry.command || [];
            if (cmd.length > 0) {
                Quickshell.execDetached([Config.terminal, "-e"].concat(cmd));
            } else {
                const exec = (entry.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
                if (exec) Quickshell.execDetached([Config.terminal, "-e", "sh", "-c", exec]);
            }
        } else {
            entry.execute();
        }
    }
}
