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

    function applyToDaemon(text) {
        let p = text;
        if (p.startsWith("~")) p = Quickshell.env("HOME") + p.slice(1);
        root.pendingApplyPath = p;
        root.pendingApplyIsVideo = ["mp4", "webm", "mkv", "mov"].includes(p.split(".").pop().toLowerCase());
        // Always clear any running mpvpaper first — harmless no-op if none
        // is running, and avoids two players fighting over the same output
        // when switching video -> video or video -> image.
        videoKillProc.running = false;
        videoKillProc.running = true;
    }

    property Process videoKillProc: Process {
        command: ["pkill", "-x", "mpvpaper"]
        onExited: {
            if (root.pendingApplyIsVideo) {
                // panscan=1.0 crops to fill the output instead of
                // letterboxing when the video's aspect ratio doesn't match
                // the screen's.
                videoProc.command = ["mpvpaper", "-o", "no-audio loop panscan=1.0", "*", root.pendingApplyPath];
                videoProc.running = false;
                videoProc.running = true;
            } else {
                applyProc.command = ["awww", "img", root.pendingApplyPath,
                    "--transition-type", Config.wallpaperTransitionStyle];
                applyProc.running = false;
                applyProc.running = true;
            }
        }
    }

    property Process videoProc: Process {}

    function setPath(text) {
        const trimmed = text.trim();
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

    property Process applyProc: Process {}

    // Best-effort: exits immediately (harmlessly) if a daemon is already
    // running from a previous shell session.
    property Process daemonProc: Process {
        command: ["awww-daemon"]
        running: true
    }

    // awww-daemon needs a moment to open its IPC socket after spawning —
    // restoreTimer gives it that before replaying the persisted path.
    property Timer restoreTimer: Timer {
        interval: 400
        onTriggered: if (root.path) root.applyToDaemon(root.path)
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
