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

            // ── Preserve actions & deep links for history ──
            // Once a notification is dismissed/expired, the live object is
            // gone and we can no longer call action.invoke(). We snapshot
            // action identifiers and any URL/deep-link now so history
            // entries can still do something useful later.
            const actions = [];
            if (notification.actions) {
                for (const a of notification.actions) {
                    actions.push({ identifier: a.identifier || "", label: a.label || "" });
                }
            }

            // Extract a usable URL from the notification body or hints.
            // Apps like Slack embed deep links as href in the body markup
            // or as a hint value. We capture the first http(s):// URL found.
            const deepLink = root._extractUrl(notification);

            root.history = [{
                summary: notification.summary || "",
                body: notification.body || "",
                appName: notification.appName || "",
                appIcon: notification.appIcon || "",
                desktopEntry: notification.desktopEntry || "",
                senderPid: senderPid,
                time: new Date(),
                // Preserved for smart open — see openNotification()
                actions: actions,
                deepLink: deepLink,
                // Keep a reference to the live notification while it exists.
                // Once dismissed this becomes null/undefined — that's fine,
                // the history entry still has the snapshot above.
                _live: notification
            }].concat(root.history).slice(0, root.historyMax);

            if (!root.dndActive) {
                root.list = [notification].concat(root.list);
            }

            // Resolve sender window address while the process is alive.
            if (senderPid) root._resolvePidAddress(senderPid);

            root._debugNotification(notification, deepLink, actions);
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

    // ── Primary entry point for the "Open" button ──
    // Works on both live notifications (from NotifyCard) and history entries
    // (from NotificationHistoryTab). Priority:
    //
    //   1. Focus an existing Hyprland window matching the app (primary —
    //      works for every app, not just ones with rich hints).
    //   2. Focus via resolved PID (for CLI notifiers like notify-send).
    //   3. Enhance with app-provided deep navigation, if present: invoke the
    //      notification's native "default" action, or open a deep link/URL
    //      from hints. These are naturally no-ops when the app (e.g. Slack)
    //      didn't supply the fields, so they never block a plain focus.
    //   4. Launch the app via its .desktop entry if nothing above found a
    //      running window.
    //
    // Returns true if any action was taken.
    function openNotification(entry) {
        if (!entry) return false;
        const appName = entry.appName || "";
        const desktop = entry.desktopEntry || "";

        // ── Step 1: Focus an existing window by app name/class ──
        let focused = root._focusByNeedles([desktop, appName]);
        if (focused) console.log("[Notifications] Focused window for:", appName);

        // ── Step 2: Focus via resolved PID ──
        // For CLI notifiers (notify-send from Ghostty, etc.) the appName
        // doesn't match any window class. The sender PID was resolved to a
        // Hyprland window address at notification arrival time.
        if (!focused) {
            const pid = entry.senderPid || 0;
            focused = root._focusByResolvedPid(pid);
            if (focused) console.log("[Notifications] Focused window via PID for:", appName);
        }

        // ── Step 3: Deep navigation enhancement (only if the app supplied it) ──
        // The source app (Slack, Teams, etc.) may register a "default"
        // action or an explicit deep-link hint to navigate to the exact
        // conversation/thread. Only fires when those fields exist — apps
        // without them simply skip this step.
        let navigated = false;
        if (root._invokeDefaultAction(entry)) {
            console.log("[Notifications] Invoked default action for:", appName);
            navigated = true;
        } else {
            // Only use URLs explicitly provided via hints — body URLs are too
            // likely to be incidental content (build logs, error messages,
            // etc.) that shouldn't hijack the open action.
            const url = entry.deepLink || "";
            if (url) {
                console.log("[Notifications] Opening deep link:", url);
                Qt.openUrlExternally(url);
                navigated = true;
            }
        }

        // Navigation may have happened on an app whose window we hadn't
        // found yet (e.g. default action alone doesn't raise the window) —
        // make sure it's also brought to front.
        if (navigated && !focused) {
            focused = root._focusByNeedles([desktop, appName]);
        }

        if (focused || navigated) return true;

        // ── Step 4: Launch via desktop entry ──
        // Only reached if the app isn't running and supplied no deep link.
        if (root._launchDesktopEntry(desktop, appName)) {
            console.log("[Notifications] Launched app:", desktop || appName);
            return true;
        }

        console.log("[Notifications] No action available for:", appName);
        return false;
    }

    // ── Legacy API kept for backward compatibility ──
    // focusApp: used by NotifyCard for live notifications (has full object).
    function focusApp(notification) {
        // For live notifications, wrap into the unified path
        // by finding the matching history entry (which holds _live ref)
        // or constructing a temporary entry.
        const entry = root._historyEntryForLive(notification) || {
            appName: notification.appName || "",
            desktopEntry: notification.desktopEntry || "",
            senderPid: (notification.hints && notification.hints["sender-pid"]) || 0,
            deepLink: root._extractUrl(notification),
            actions: [],
            _live: notification
        };
        return root.openNotification(entry);
    }

    // openApp: used by NotificationHistoryTab for history entries.
    function openApp(entry) {
        return root.openNotification(entry);
    }

    // ─── Private: Action invocation ──────────────────────────────────────

    // Invokes the "default" action on a live notification object.
    // The freedesktop spec defines "default" as the action triggered when
    // you click the notification body — this is what Slack uses to navigate
    // to the exact channel/thread. Returns true if invoked.
    function _invokeDefaultAction(entry) {
        // Try the live notification reference first
        const live = entry._live;
        if (live && live.actions) {
            const defaultAction = live.actions.find(a => a.identifier === "default");
            if (defaultAction) {
                defaultAction.invoke();
                return true;
            }
            // Some apps use empty-string identifier for default
            const emptyAction = live.actions.find(a => a.identifier === "");
            if (emptyAction) {
                emptyAction.invoke();
                return true;
            }
        }
        return false;
    }

    // ─── Private: URL extraction ─────────────────────────────────────────

    // Extracts a deep link URL from notification hints only.
    // We intentionally do NOT parse URLs from the body text — body content
    // often contains incidental URLs (build logs, error messages, docs links)
    // that shouldn't hijack the "open" action. Only explicit app-provided
    // hints represent intentional deep links.
    function _extractUrl(notification) {
        if (!notification.hints) return "";

        // Standard hint keys apps use for deep links
        const hintUrl = notification.hints["x-url"]
            || notification.hints["url"]
            || notification.hints["desktop-entry-url"]
            || "";
        if (hintUrl && /^https?:\/\//.test(hintUrl)) return hintUrl;

        // Slack-specific: sometimes uses "x-deeplink"
        const deeplink = notification.hints["x-deeplink"] || "";
        if (deeplink && /^(https?|slack):\/\//.test(deeplink)) return deeplink;

        return "";
    }

    // ─── Private: Window focus ───────────────────────────────────────────

    // Tries app class first (exact/substring match), then falls back to
    // window title.
    function _focusByNeedles(candidates) {
        const needles = candidates.map(c => (c || "").toLowerCase()).filter(c => c.length > 0);
        if (needles.length === 0) return false;

        // Match by Hyprland window class (from IPC object)
        for (const top of Hyprland.toplevels.values) {
            const ipc = top.lastIpcObject;
            const appClass = (ipc ? (ipc.class || ipc.initialClass || "") : "").toLowerCase();
            if (needles.some(n => appClass && (appClass === n || appClass.includes(n) || n.includes(appClass)))) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        // Fallback: match by window title
        for (const top of Hyprland.toplevels.values) {
            const title = (top.title || "").toLowerCase();
            if (needles.some(n => title && title.includes(n))) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
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
        if (!addr) return false;
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${addr}" })`);
        return true;
    }

    // ─── Private: PID-based window resolution ────────────────────────────

    property var _pidAddressCache: ({})
    // Queue of PIDs waiting to be resolved (single Process can only handle
    // one at a time).
    property var _pidResolveQueue: []

    property Process pidResolver: Process {
        property int forPid: 0
        stdout: StdioCollector {
            onStreamFinished: {
                const address = text.trim();
                if (address) {
                    root._pidAddressCache[pidResolver.forPid] = address;
                    console.log("[Notifications] PID", pidResolver.forPid, "resolved to:", address);
                } else {
                    console.log("[Notifications] PID", pidResolver.forPid, "could not be resolved");
                }
                // Process next in queue
                root._processNextPid();
            }
        }
    }

    function _resolvePidAddress(pid) {
        // Skip if already cached or already queued
        if (root._pidAddressCache[pid]) return;
        if (root._pidResolveQueue.indexOf(pid) >= 0) return;
        if (root.pidResolver.forPid === pid && root.pidResolver.running) return;

        root._pidResolveQueue.push(pid);
        if (!root.pidResolver.running) root._processNextPid();
    }

    function _processNextPid() {
        if (root._pidResolveQueue.length === 0) return;
        const pid = root._pidResolveQueue.shift();
        root.pidResolver.forPid = pid;
        root.pidResolver.command = ["sh", "-c",
            'p="$1"; while [ -n "$p" ] && [ "$p" != "1" ] && [ "$p" != "0" ]; do ' +
            'addr=$(/usr/bin/hyprctl clients -j | /usr/bin/jq -r --arg p "$p" \'.[] | select((.pid|tostring)==$p) | .address\' 2>/dev/null); ' +
            '[ -n "$addr" ] && { echo "${addr#0x}"; exit 0; }; ' +
            'p=$(/usr/bin/awk \'/^PPid:/{print $2}\' /proc/"$p"/status 2>/dev/null); ' +
            '[ -z "$p" ] && exit 1; ' +
            'done; exit 1',
            "_", String(pid)];
        root.pidResolver.running = false;
        root.pidResolver.running = true;
    }

    function _focusByResolvedPid(pid) {
        if (!pid) return false;

        // Fast path: already resolved and cached at notification arrival
        const address = root._pidAddressCache[pid];
        if (address) {
            console.log("[Notifications] PID", pid, "resolved to cached address:", address);
            return root._activateByAddress(address);
        }

        // Direct PID match against current Hyprland clients
        for (const top of Hyprland.toplevels.values) {
            const ipc = top.lastIpcObject;
            if (ipc && Number(ipc.pid) === Number(pid)) {
                console.log("[Notifications] PID", pid, "directly matches client:", top.address);
                root._pidAddressCache[pid] = String(top.address || "").replace(/^0x/, "");
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }

        // The sender process (e.g. notify-send) likely exited already.
        // The async resolver should have cached the parent terminal's
        // address at arrival time. If it failed or hasn't run yet,
        // re-trigger for next click.
        console.log("[Notifications] PID", pid, "not found in cache or clients, re-resolving");
        root._resolvePidAddress(pid);
        return false;
    }

    function _activateByAddress(address) {
        if (!address) return false;
        const needle = String(address).replace(/^0x/, "");
        for (const top of Hyprland.toplevels.values) {
            const topAddr = String(top.address || "").replace(/^0x/, "");
            if (topAddr && topAddr === needle) {
                root._hyprctlFocusWindow(top.address);
                return true;
            }
        }
        return false;
    }

    // ─── Private: Desktop entry launching ────────────────────────────────

    // Finds and launches a .desktop entry matching the notification's
    // desktopEntry field or appName. Only fires if no window was found
    // (i.e., the app isn't running).
    function _launchDesktopEntry(desktopId, appName) {
        const entries = DesktopEntries.applications.values;
        const needles = [desktopId, appName].map(s => (s || "").toLowerCase()).filter(s => s.length > 0);
        if (needles.length === 0) return false;

        for (const entry of entries) {
            if (entry.noDisplay) continue;
            const entryId = (entry.id || "").toLowerCase();
            const entryName = (entry.name || "").toLowerCase();
            // Match by desktop ID (e.g., "com.slack.Slack" or "slack")
            if (needles.some(n => entryId === n || entryId.includes(n) || n.includes(entryId) ||
                                  entryName === n)) {
                root._launchEntry(entry);
                return true;
            }
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

    // ─── Private: History lookup ─────────────────────────────────────────

    // Finds the history entry that corresponds to a live notification
    // (used by focusApp() to route through the unified openNotification path).
    function _historyEntryForLive(notification) {
        for (const h of root.history) {
            if (h._live === notification) return h;
        }
        return null;
    }

    // ─── Private: Debug logging ──────────────────────────────────────────

    function _debugNotification(notification, deepLink, actions) {
        console.log("[Notifications] ──────────────────────────────────");
        console.log("[Notifications] appName:", notification.appName || "(empty)");
        console.log("[Notifications] desktopEntry:", notification.desktopEntry || "(empty)");
        console.log("[Notifications] summary:", notification.summary || "(empty)");
        console.log("[Notifications] body:", (notification.body || "").substring(0, 120));
        console.log("[Notifications] actions:", JSON.stringify(actions));
        console.log("[Notifications] deepLink:", deepLink || "(none)");
        console.log("[Notifications] hints:", JSON.stringify(notification.hints || {}));
        console.log("[Notifications] ──────────────────────────────────");
    }
}
