pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Resolves a desktop entry / app name to a running Hyprland window, or
// launches it fresh. The one seam for "bring this app forward, or start
// it" — the launcher's Enter/click path and a notification's Open action
// used to keep separate copies of this; both call through here now.
QtObject {
    id: root

    function windowAddress(desktopEntry, appName) {
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

    // Hyprland 0.56 uses Lua dispatcher expressions. Quickshell sends this
    // expression over Hyprland's IPC socket without spawning hyprctl.
    function _focusRequest(address) {
        const addr = String(address || "").replace(/^0x/, "");
        return addr ? `hl.dsp.focus({ window = "address:0x${addr}" })` : "";
    }

    function focusWindow(desktopEntry, appName) {
        const address = root.windowAddress(desktopEntry, appName);
        if (!address) return false;
        const request = root._focusRequest(address);
        if (request) Hyprland.dispatch(request);
        return true;
    }

    property string _pendingDesktopEntry: ""
    property string _pendingAppName: ""
    property int _attemptsRemaining: 0

    readonly property Timer _retryTimer: Timer {
        interval: 100
        repeat: true
        onTriggered: {
            root.focusWindow(root._pendingDesktopEntry, root._pendingAppName);
            root._attemptsRemaining--;
            if (root._attemptsRemaining <= 0) stop();
        }
    }

    // Retries focusWindow() a few times shortly after — for an app whose
    // window takes a beat to map once its action fires.
    function focusWithRetry(desktopEntry, appName, attempts) {
        root._pendingDesktopEntry = desktopEntry;
        root._pendingAppName = appName;
        root._attemptsRemaining = attempts || 3;
        root._retryTimer.restart();
    }

    // heuristicLookup("") does NOT return null — it returns some arbitrary
    // entry (seen returning org.gnome.Maps / org.gnome.DiskUtility) — so a
    // caller with no desktop-entry hint (e.g. notify-send) must never reach
    // it with an empty string, or this resolves to a random unrelated app.
    function resolveEntry(desktopEntry, appName) {
        const desktop = desktopEntry || "";
        const name = appName || "";
        const target = (desktop && DesktopEntries.heuristicLookup(desktop))
            || (name && DesktopEntries.heuristicLookup(name));
        return (target && !target.noDisplay) ? target : null;
    }

    // Launches a resolved desktop entry, wrapping terminal apps (btop, nvim,
    // etc.) in the configured terminal — Quickshell's DesktopEntry.execute()
    // does NOT spawn a terminal even when runInTerminal is true.
    function launch(entry) {
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

    // Focuses a running window for this app, or resolves + launches its
    // desktop entry fresh. For callers with no live object to act on, just
    // identifiers — a notification history entry, say.
    function focusOrLaunch(desktopEntry, appName) {
        if (root.focusWindow(desktopEntry, appName)) return true;
        const target = root.resolveEntry(desktopEntry, appName);
        if (target) {
            root.launch(target);
            return true;
        }
        return false;
    }
}
