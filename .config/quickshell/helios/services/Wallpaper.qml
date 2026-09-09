pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Wallpaper display itself is owned by an external daemon — awww for
// still/animated images (layer-shell surface per output), mpvpaper for
// video files (mpv can't be driven by awww) — this service only tracks the
// selected path/folder and drives their CLIs. Persisted the same way as
// Weather's location override — FileView + JsonAdapter. folderPath is
// scanned for images (find, one process call); picking one in
// WallpaperSettings just calls setPath.
QtObject {
    id: root

    readonly property string path: settingsAdapter.path
    readonly property string folderPath: settingsAdapter.folderPath
    property var images: []

    readonly property bool isVideo: {
        const ext = root.path.split(".").pop().toLowerCase();
        return ["mp4", "webm", "mkv", "mov"].includes(ext);
    }

    // file:// URL for QML Image/MediaPlayer previews (hero preview, thumbs)
    // — display itself no longer binds to this.
    readonly property string source: {
        if (!root.path) return "";
        let p = root.path;
        if (p.startsWith("~")) p = Quickshell.env("HOME") + p.slice(1);
        return p.startsWith("/") ? "file://" + p : p;
    }

    property string pendingApplyPath: ""
    property bool pendingApplyIsVideo: false
    property string pendingTransitionType: "simple"
    property bool daemonKilled: false

    function applyToDaemon(text, isRestore) {
        if (!text) return;
        let p = text;
        if (p.startsWith("~")) p = Quickshell.env("HOME") + p.slice(1);
        root.pendingApplyPath = p;
        root.pendingApplyIsVideo = ["mp4", "webm", "mkv", "mov"].includes(p.split(".").pop().toLowerCase());
        // Restore is re-asserting whatever's already showing (the common
        // case, since awww-daemon survives a plain quickshell restart) —
        // "simple" is the fastest, least eventful transition, instead of
        // replaying the user's chosen fancy transition over an image that
        // isn't actually changing.
        root.pendingTransitionType = isRestore ? "simple" : Config.wallpaperTransitionStyle;
        // Always clear any running mpvpaper first — harmless no-op if none
        // is running, and avoids two players fighting over the same output
        // when switching video -> video or video -> image.
        videoKillProc.running = false;
        videoKillProc.running = true;
    }

    property Process videoKillProc: Process {
        // mpvpaper can remain alive after SIGTERM once its Wayland surface
        // fails. Force cleanup so the replacement can claim every output.
        command: ["pkill", "-KILL", "-x", "mpvpaper"]
        onExited: {
            if (root.pendingApplyIsVideo) {
                // panscan=1.0 crops to fill the output instead of
                // letterboxing when the video's aspect ratio doesn't match
                // the screen's.
                videoProc.command = ["mpvpaper", "-o", "no-audio loop panscan=1.0 hwdec=auto", "*", root.pendingApplyPath];
                videoProc.running = false;
                videoProc.running = true;
                // awww-daemon keeps its decoded image buffer resident even
                // while mpvpaper owns the output — that's the ~1GB idle RAM
                // hit. Kill it during video playback; the video->image
                // branch below respawns it before the next image apply.
                daemonKillProc.running = false;
                daemonKillProc.running = true;
                root.daemonKilled = true;
            } else if (root.daemonKilled) {
                // Video -> image: daemon was killed above, respawn it and
                // give it the same startup grace as restoreTimer before
                // pushing the image.
                root.daemonKilled = false;
                daemonProc.running = false;
                daemonProc.running = true;
                daemonRespawnTimer.start();
            } else {
                root.applyRetryCount = 0;
                applyProc.command = ["awww", "img", root.pendingApplyPath,
                    "--transition-type", root.pendingTransitionType, "--transition-step", 255, "--transition-fps", 144];
                applyProc.running = false;
                applyProc.running = true;
            }
        }
    }

    property Process daemonKillProc: Process { command: ["awww", "kill"] }

    property Timer daemonRespawnTimer: Timer {
        interval: 400
        onTriggered: {
            root.applyRetryCount = 0;
            applyProc.command = ["awww", "img", root.pendingApplyPath,
                "--transition-type", root.pendingTransitionType, "--transition-step", 255, "--transition-fps", 144];
            applyProc.running = false;
            applyProc.running = true;
        }
    }

    property Process videoProc: Process {}

    // See applyProc below for why a failed apply gets retried.
    property int applyRetryCount: 0

    property Timer applyRetryTimer: Timer {
        interval: 500
        onTriggered: { applyProc.running = false; applyProc.running = true; }
    }

    function setPath(text) {
        const trimmed = text.trim();
        if (!trimmed) return;
        settingsAdapter.path = trimmed;
        root.settingsFile.writeAdapter();
        root.applyToDaemon(trimmed);

        // Keeps the dynamic (matugen) theme in sync with the wallpaper
        // automatically — Themes.applyDynamic() is itself debounced, so
        // rapid picks/scans here don't pile up matugen processes.
        if (Themes.mode === "dynamic") Themes.applyDynamic();
    }

    function setFolder(text) {
        settingsAdapter.folderPath = text.trim();
        root.settingsFile.writeAdapter();
        root.scanFolder();
    }

    function scanFolder() {
        if (!settingsAdapter.folderPath) { root.images = []; return; }
        let dir = settingsAdapter.folderPath;
        if (dir.startsWith("~")) dir = Quickshell.env("HOME") + dir.slice(1);
        folderScanner.command = ["sh", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.avif" -o -iname "*.jxl" -o -iname "*.tiff" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \\) 2>/dev/null | sort',
            "sh", dir];
        folderScanner.running = false;
        folderScanner.running = true;
    }

    property Process folderScanner: Process {
        stdout: StdioCollector {
            onStreamFinished: root.images = text.split("\n").filter(l => l.length > 0)
        }
    }

    // awww-daemon (0.12.1-3.fc44, at least) panics and aborts on its own
    // fairly regularly — confirmed via `coredumpctl list`, dozens of
    // SIGABRT crashes, sometimes just seconds apart, unrelated to any
    // particular image. Once it's dead, `awww img` fails immediately with
    // "failed to connect to socket: Connection refused" against the stale
    // socket file it leaves behind, and the output goes black until
    // something respawns it. A failed apply almost always means exactly
    // this, not "daemon is merely slow" — so respawn (harmless no-op if
    // it's actually still alive) before retrying, instead of retrying the
    // same command against a socket nothing is listening on.
    property Process applyProc: Process {
        onExited: exitCode => {
            if (exitCode !== 0 && root.applyRetryCount < 3) {
                root.applyRetryCount++;
                daemonProc.running = false;
                daemonProc.running = true;
                applyRetryTimer.start();
            } else {
                root.applyRetryCount = 0;
            }
        }
    }

    // Best-effort: exits immediately (harmlessly) if a daemon is already
    // running — either from a previous shell session, or because this is
    // just a respawn-after-crash retry above finding it already back up.
    property Process daemonProc: Process {
        command: ["awww-daemon"]
        running: true
    }

    // A plain `helios-reload.sh` restart (SUPER+SHIFT+R) kills and relaunches
    // only quickshell — awww-daemon isn't in that pkill pattern, so it
    // survives and is already displaying the right image before this even
    // runs. This replay exists for the other case: a genuine cold start,
    // where the daemon really is a fresh spawn and needs the 400ms head
    // start before its IPC socket is up.
    property Timer restoreTimer: Timer {
        interval: 400
        onTriggered: if (root.path) root.applyToDaemon(root.path, true)
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("wallpaper.json")
        watchChanges: true
        onLoaded: { root.scanFolder(); root.restoreTimer.start(); }

        JsonAdapter {
            id: settingsAdapter
            property string path: ""
            property string folderPath: ""
        }
    }
}
