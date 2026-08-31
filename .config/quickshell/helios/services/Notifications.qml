pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland

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

    property string _pendingFocusDesktopEntry: ""
    property string _pendingFocusAppName: ""
    property int _focusAttemptsRemaining: 0

    readonly property Timer _actionFocusTimer: Timer {
        interval: 100
        repeat: true

        onTriggered: {
            root._focusByClass(root._pendingFocusDesktopEntry, root._pendingFocusAppName);
            root._focusAttemptsRemaining--;
            if (root._focusAttemptsRemaining <= 0) stop();
        }
    }

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

    function _windowAddress(desktopEntry, appName) {
        const needles = [desktopEntry, appName].map(s => (s || "").toLowerCase()).filter(s => s.length > 0);
        if (needles.length === 0) return "";
        for (const top of Hyprland.toplevels.values) {
            const ipc = top.lastIpcObject;
            const cls = (ipc ? (ipc.class || ipc.initialClass || "") : "").toLowerCase();
            if (needles.some(n => cls && (cls === n || cls.includes(n) || n.includes(cls)))) {
                return String(top.address || "");
            }
        }
        return "";
    }

    function _focusByClass(desktopEntry, appName) {
        const address = root._windowAddress(desktopEntry, appName);
        if (!address) return false;
        root._dispatchFocusWindow(address);
        return true;
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
                root._focusByClass(desktopEntry, appName);
                root._scheduleActionFocus(desktopEntry, appName);
            }

            return true;
        }

        return root._focusByClass(desktopEntry, appName);
    }

    function _scheduleActionFocus(desktopEntry, appName) {
        root._pendingFocusDesktopEntry = desktopEntry;
        root._pendingFocusAppName = appName;
        root._focusAttemptsRemaining = 3;
        root._actionFocusTimer.restart();
    }

    // ── "Open" for a history entry (NotificationHistoryTab) ──
    // History entries have no live DBus object left to invoke an action on.
    // Focus a matching window, or relaunch through its desktop entry.
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

    function openApp(entry) {
        if (!entry) return false;
        if (root._focusByClass(entry.desktopEntry, entry.appName)) return true;
        const target = root._resolveEntry(entry);
        if (target) {
            root._launchEntry(target);
            return true;
        }
        return false;
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

    // Hyprland 0.56 uses Lua dispatcher expressions. Quickshell sends this
    // expression over Hyprland's IPC socket without spawning hyprctl.
    function _focusRequest(address) {
        const addr = String(address || "").replace(/^0x/, "");
        return addr ? `hl.dsp.focus({ window = "address:0x${addr}" })` : "";
    }

    function _dispatchFocusWindow(address) {
        const request = root._focusRequest(address);
        if (request) Hyprland.dispatch(request);
    }
}
