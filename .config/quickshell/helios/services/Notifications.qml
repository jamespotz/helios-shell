pragma Singleton
import QtQuick
import Quickshell.Io
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
            const senderPid = (notification.hints && notification.hints["sender-pid"]) || 0;
            // Always add to history regardless of DND state
            root.history = [{ summary: notification.summary, body: notification.body,
                appName: notification.appName, appIcon: notification.appIcon,
                desktopEntry: notification.desktopEntry,
                senderPid: senderPid,
                time: new Date() }].concat(root.history).slice(0, root.historyMax);
            // Only show popup if DND is off
            if (!root.dndActive) {
                root.list = [notification].concat(root.list);
            }
            // Resolve the sender's window address *now*, while its process
            // (or an ancestor) is still alive — CLI notifiers like
            // `notify-send` exit within milliseconds, so waiting until the
            // user actually clicks "open" is too late to walk /proc for it.
            if (senderPid) root._resolvePidAddress(senderPid);
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
    // First invokes the notification's "default" action if it has one —
    // per the freedesktop notification spec, that's what a real desktop
    // environment triggers when you click a notification's body, and it's
    // what makes apps like Slack navigate to the actual channel/thread that
    // triggered it rather than just opening to whatever was last visible.
    // Window-focus-by-appId still runs afterward regardless, since invoking
    // the action isn't guaranteed to raise the window on its own, and not
    // every app registers a default action in the first place.
    function focusApp(notification) {
        const defaultAction = notification.actions ? notification.actions.find(a => a.identifier === "default") : null;
        if (defaultAction) defaultAction.invoke();

        const pid = (notification.hints && notification.hints["sender-pid"]) || 0;
        const matched = root._focusByNeedles([notification.desktopEntry, notification.appName]) || root._focusByResolvedPid(pid);
        return matched || !!defaultAction;
    }

    // Same window-raise used by focusApp, but for a plain history entry
    // (no live notification/actions left to invoke — those only exist while
    // the notification is tracked).
    function openApp(entry) {
        return root._focusByNeedles([entry.desktopEntry, entry.appName]) || root._focusByResolvedPid(entry.senderPid || 0);
    }

    // Tries appId first (exact/substring match), then falls back to window
    // title — CLI tools that forward notifications through a terminal (e.g.
    // `notify-send` from inside Ghostty) often report their own name rather
    // than the terminal's desktop entry, so appId alone won't match; the
    // title often still mentions the tool/command.
    function _focusByNeedles(candidates) {
        const needles = candidates.map(c => (c || "").toLowerCase()).filter(c => c.length > 0);
        if (needles.length === 0) return false;

        for (const top of Hyprland.toplevels.values) {
            const appId = (top.wayland && top.wayland.appId || "").toLowerCase();
            if (needles.some(n => appId && (appId === n || appId.includes(n) || n.includes(appId)))) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        for (const top of Hyprland.toplevels.values) {
            const title = (top.wayland && top.wayland.title || "").toLowerCase();
            if (needles.some(n => title && title.includes(n))) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        return false;
    }

    // Focuses a client by Hyprland address via hyprctl's "focuswindow"
    // dispatcher — unlike the plain wlr-foreign-toplevel activate() call,
    // this reliably switches to the client's workspace first when it's on a
    // different one, which is what a notification's "open app" action needs.
    property Process focusProc: Process {}
    function _hyprctlFocusWindow(address) {
        const addr = String(address || "").replace(/^0x/, "");
        if (!addr) return false;
        root.focusProc.command = ["hyprctl", "dispatch", "focuswindow", "address:0x" + addr];
        root.focusProc.running = false;
        root.focusProc.running = true;
        return true;
    }

    // Last-resort fallback for CLI tools that forward notifications through
    // a terminal (e.g. `notify-send` from a Claude Code hook inside Ghostty):
    // their appName/desktopEntry has no relation to the terminal's window,
    // so name matching can never find it. The DBus "sender-pid" hint gives
    // the notifier's PID instead. That PID is walked up to a Hyprland client
    // *immediately* on arrival (see onNotification) rather than when the
    // user later clicks "open" — CLI notifiers like `notify-send` exit
    // within milliseconds, so their /proc entry (and thus the ability to
    // read its parent) is long gone by click time. The resolved window
    // address is cached here and reused by both the live popup and history.
    property var _pidAddressCache: ({})

    property Process pidResolver: Process {
        property int forPid: 0
        stdout: StdioCollector {
            onStreamFinished: {
                const address = text.trim();
                if (address) root._pidAddressCache[pidResolver.forPid] = address;
            }
        }
    }
    function _resolvePidAddress(pid) {
        root.pidResolver.forPid = pid;
        root.pidResolver.command = ["sh", "-c",
            'p="$1"; while [ -n "$p" ]; do ' +
            'addr=$(/usr/bin/hyprctl clients -j | /usr/bin/jq -r --arg p "$p" \'.[] | select((.pid|tostring)==$p) | .address\' 2>/dev/null); ' +
            '[ -n "$addr" ] && { echo "${addr#0x}"; exit 0; }; ' +
            'p=$(/usr/bin/awk \'/^PPid:/{print $2}\' /proc/$p/status 2>/dev/null); ' +
            'done; exit 1',
            "_", String(pid)];
        root.pidResolver.running = false;
        root.pidResolver.running = true;
    }

    // Uses an already-resolved address if we have one (fast path, works even
    // long after the sender exited); otherwise makes a best-effort live
    // attempt in case the process is still around.
    function _focusByResolvedPid(pid) {
        if (!pid) return false;
        const address = root._pidAddressCache[pid];
        if (address) return root._activateByAddress(address);
        root._resolvePidAddress(pid);
        return false;
    }
    function _activateByAddress(address) {
        for (const top of Hyprland.toplevels.values) {
            if ((top.address || "") === address) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        return false;
    }
}
