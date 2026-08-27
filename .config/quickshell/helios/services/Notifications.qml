pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

            const senderPid = (notification.hints && notification.hints["sender-pid"]) || 0;

            root.history = [{
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                appIcon: notification.appIcon || "",
                desktopEntry: notification.desktopEntry || "",
                senderPid: senderPid,
                time: new Date(),
                actions: notification.actions || undefined
            }].concat(root.history).slice(0, root.historyMax);

            if (!root.dndActive) {
                root.list = [notification].concat(root.list);
            }

            // Warm the PID->window cache now, while the sender process is
            // still likely alive, so a later click resolves instantly.
            if (senderPid) root._resolvePid(senderPid);
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
    // But invoking it is not enough on its own: confirmed live, real Slack
    // notifications carry a "default" action and a desktopEntry hint but no
    // appName or sender-pid, and invoking the action makes Slack navigate
    // internally without raising its window (a known Linux/Electron quirk).
    // So we always also try focusing the window by class — cheap and
    // synchronous, unlike the PID resolver, since it just checks the
    // already-live Hyprland.toplevels list rather than racing a subprocess.
    function _findDefaultAction(notification) {
        if (!notification || !notification.actions) return null;
        return notification.actions.find(a => a.identifier === "default")
            || notification.actions.find(a => a.identifier === "")
            || null;
    }

    function _senderPid(notification) {
        return (notification && notification.hints && notification.hints["sender-pid"]) || 0;
    }

    function _focusByClass(desktopEntry, appName) {
        const needles = [desktopEntry, appName].map(s => (s || "").toLowerCase()).filter(s => s.length > 0);
        if (needles.length === 0) return false;
        for (const top of Hyprland.toplevels.values) {
            const ipc = top.lastIpcObject;
            const cls = (ipc ? (ipc.class || ipc.initialClass || "") : "").toLowerCase();
            if (needles.some(n => cls && (cls === n || cls.includes(n) || n.includes(cls)))) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        return false;
    }

    // Whether NotifyCard should show the Open icon for this live notification.
    // True for a registered default action OR a desktopEntry we can match
    // against a running window — the PID resolver alone doesn't count here
    // since its low hit rate for fast-exiting CLI tools isn't worth an icon.
    function hasDefaultAction(notification) {
        return !!root._findDefaultAction(notification)
            || !!(notification && notification.desktopEntry);
    }

    function focusApp(notification) {
        if (!notification) return false;
        // Invoke first, then raise — invoking can itself cause the app to
        // navigate/steal its own focus state (see comment above), so the
        // class-based raise must happen last to actually win.
        const action = root._findDefaultAction(notification);
        if (action) action.invoke();
        const focused = root._focusByClass(notification.desktopEntry, notification.appName);
        if (focused || action) return true;
        return root._focusByPid(root._senderPid(notification));
    }

    // ── "Open" for a history entry (NotificationHistoryTab) ──
    // History entries have no live DBus object left to invoke an action on.
    // Try focusing a still-running window first (cheap, reliable) — only
    // relaunch via the .desktop entry if nothing is running, then fall back
    // to the PID resolver as a last resort.
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
        return root._focusByPid(entry.senderPid);
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

    // ─── PID-based window resolution (for CLI notifiers like notify-send) ──
    // notify-send only gives us its own PID via the "sender-pid" hint, not
    // which app invoked it. We walk /proc's parent-PID chain up from that
    // PID and focus the first ancestor that matches a running Hyprland
    // client — matching happens in QML against the already-live
    // Hyprland.toplevels list, so the shell side only has to print the PID
    // chain (no hyprctl/jq round trip needed there).

    // senderPid -> window address ("" if no match was found), once resolved.
    property var _pidWindowCache: ({})
    property var _pidResolveQueue: []

    property Process _pidWalker: Process {
        property int forPid: 0
        stdout: StdioCollector {
            onStreamFinished: root._onPidWalked(_pidWalker.forPid, text)
        }
    }

    function _resolvePid(pid) {
        if (!pid || root._pidWindowCache[pid] !== undefined) return;
        if (root._pidResolveQueue.includes(pid)) return;
        root._pidResolveQueue.push(pid);
        if (!root._pidWalker.running) root._walkNextPid();
    }

    function _walkNextPid() {
        if (root._pidResolveQueue.length === 0) return;
        const pid = root._pidResolveQueue.shift();
        root._pidWalker.forPid = pid;
        // Pure shell builtins (read/case), no awk — one fork+exec total
        // instead of one per hop. Matters because notify-send-style tools
        // exit within a few ms of sending their notification; every extra
        // process spawn is latency we can lose the race on.
        root._pidWalker.command = ["sh", "-c",
            'p="$1"; while [ -n "$p" ] && [ "$p" != "1" ] && [ "$p" != "0" ]; do ' +
            'echo "$p"; ppid=""; ' +
            'while IFS=$(printf "\\t") read -r k v; do case "$k" in PPid:) ppid="$v"; break;; esac; done < "/proc/$p/status" 2>/dev/null; ' +
            'p="$ppid"; done',
            "_", String(pid)];
        root._pidWalker.running = true;
    }

    function _onPidWalked(pid, chainText) {
        const chain = chainText.trim().split("\n").map(s => parseInt(s)).filter(n => n);
        let address = "";
        for (const top of Hyprland.toplevels.values) {
            const ipc = top.lastIpcObject;
            const p = ipc ? Number(ipc.pid) : 0;
            if (p && chain.includes(p)) {
                address = String(top.address || "");
                break;
            }
        }
        root._pidWindowCache[pid] = address;
        root._walkNextPid();
    }

    function _focusByPid(pid) {
        if (!pid) return false;
        const cached = root._pidWindowCache[pid];
        if (cached) {
            root._hyprctlFocusWindow(cached);
            return true;
        }
        if (cached === "") return false; // already resolved — no matching window

        // Not resolved yet (sender process may have already exited before
        // arrival-time resolution finished) — kick it off for next time.
        root._resolvePid(pid);
        return false;
    }

    // Uses Quickshell's Hyprland IPC socket directly rather than shelling out
    // to the `hyprctl` binary — on this machine's Lua-config Hyprland fork,
    // `hyprctl dispatch focuswindow address:...` silently fails (it evaluates
    // dispatch payloads as Lua; see the same issue worked around in
    // PowerMenu.qml for the `exit` dispatcher). Hyprland.usingLua was tried
    // first but reports false on this machine (confirmed live), so — same as
    // PowerMenu.qml — the lua-form dispatcher is used unconditionally rather
    // than relying on runtime detection.
    function _hyprctlFocusWindow(address) {
        const addr = String(address || "").replace(/^0x/, "");
        if (!addr) return;
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${addr}" })`);
    }
}
