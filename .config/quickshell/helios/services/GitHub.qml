pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// GitHub notifications through the signed-in gh CLI. GitHub has no push for
// notifications, so this polls at the interval GitHub asks for
// (X-Poll-Interval, at least 60 s) with If-Modified-Since; an unchanged inbox
// answers 304, which doesn't count against the rate limit. Opening or
// marking a thread read updates GitHub too, so the GitHub destination is the
// real inbox. Sign-in problems stop polling until refresh(); other failures
// (offline) back off to five minutes.
QtObject {
    id: root

    readonly property GitHubCore _core: GitHubCore { dndActive: ShellState.dndEnabled }
    readonly property var items: root._core.items
    readonly property var popups: root._core.popups
    // A poll brought threads that got a card (not suppressed by DND); the newest.
    signal popupAdded(var record)

    property string error: ""
    property bool _signedOut: false
    property bool checking: false
    property string _lastModified: ""
    property int _pollSeconds: 60

    function refresh() {
        root._signedOut = false;
        root._poll();
    }

    function open(id) {
        const record = root.items.find(r => r.id === id);
        if (!record) return false;
        Quickshell.execDetached(["xdg-open", record.url]);
        return root.markRead(id);
    }

    function markRead(id) {
        if (!root._core.markRead(id)) return false;
        root._lastModified = "";
        Quickshell.execDetached(["gh", "api", "--silent", "-X", "PATCH", "notifications/threads/" + id]);
        return true;
    }

    function markAllRead() {
        root._core.markAllRead();
        root._lastModified = "";
        Quickshell.execDetached(["gh", "api", "--silent", "-X", "PUT", "notifications", "-F", "read=true"]);
    }

    function hidePopup(id) { root._core.hidePopup(id); }
    function hideAllPopups() { root._core.hideAllPopups(); }

    function _poll() {
        if (pollProc.running) return;
        root.checking = true;
        const header = root._lastModified ? ["-H", "If-Modified-Since: " + root._lastModified] : [];
        pollProc.command = ["sh", "-c", 'command -v gh >/dev/null || { echo "gh-missing" >&2; exit 127; }; exec "$@"',
            "sh", "gh", "api", "-i"].concat(header, ["notifications?per_page=50"]);
        pollProc.running = true;
    }

    // gh -i prints the status line and headers, a blank line, then the body.
    // A 304 exits 1 with an empty body, so the status line decides.
    function _handle(output, stderr) {
        root.checking = false;
        const split = output.search(/\r?\n\r?\n/);
        const head = split >= 0 ? output.slice(0, split) : output;
        const body = split >= 0 ? output.slice(split).trim() : "";
        const status = Number((/^HTTP\/\S+\s+(\d+)/.exec(head) || [])[1] || 0);
        const header = name => ((new RegExp("^" + name + ":\\s*(.+?)\\s*$", "mi")).exec(head) || [])[1] || "";
        if (status === 200 || status === 304) {
            root.error = "";
            root._pollSeconds = Math.max(60, Number(header("X-Poll-Interval")) || 60);
            if (status === 304) return;
            try {
                root._lastModified = header("Last-Modified");
                const fresh = root._core.ingest(JSON.parse(body));
                // Once per poll, so a burst of threads plays one sound.
                if (!root._core.dndActive && fresh.length > 0) root.popupAdded(fresh[0]);
            } catch (e) {
                console.warn("[GitHub] failed to parse notifications:", e);
            }
            return;
        }
        const message = stderr.trim();
        root._signedOut = status === 401 || /gh-missing|auth login|not logged/i.test(message);
        root.error = /gh-missing/.test(message) ? "GitHub CLI (gh) isn't installed"
            : root._signedOut ? "Not signed in to GitHub CLI. Run gh auth login"
            : "Couldn't reach GitHub";
        root._pollSeconds = 300;
    }

    property Process pollProc: Process {
        stdout: StdioCollector { id: pollOut }
        stderr: StdioCollector { id: pollErr }
        onExited: root._handle(pollOut.text, pollErr.text)
    }

    property Timer pollTimer: Timer {
        interval: root._pollSeconds * 1000
        running: !root._signedOut
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }
}
