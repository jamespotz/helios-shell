pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// Background image, one per screen (see modules/wallpaper/Wallpaper.qml).
// Persisted the same way as Weather's location override — FileView +
// JsonAdapter. folderPath is scanned for images (find, one process call);
// picking one in WallpaperSettings just calls setPath.
QtObject {
    id: root

    readonly property string path: settingsAdapter.path
    readonly property string folderPath: settingsAdapter.folderPath
    property var images: []

    // file:// URLs need forward slashes and no ~ — expand and normalize here
    // once so every screen's Image just binds to this directly.
    readonly property string source: {
        if (!root.path) return "";
        let p = root.path;
        if (p.startsWith("~")) p = Quickshell.env("HOME") + p.slice(1);
        return p.startsWith("/") ? "file://" + p : p;
    }

    function setPath(text) {
        settingsAdapter.path = text.trim();
        root.settingsFile.writeAdapter();
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
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \\) 2>/dev/null | sort',
            "sh", dir];
        folderScanner.running = false;
        folderScanner.running = true;
    }

    property Process folderScanner: Process {
        stdout: StdioCollector {
            onStreamFinished: root.images = text.split("\n").filter(l => l.length > 0)
        }
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("wallpaper.json")
        watchChanges: true
        onLoaded: root.scanFolder()

        JsonAdapter {
            id: settingsAdapter
            property string path: ""
            property string folderPath: ""
        }
    }
}
