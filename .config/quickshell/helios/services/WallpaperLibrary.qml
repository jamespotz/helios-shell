pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

QtObject {
    id: root

    readonly property string path: settingsAdapter.path
    readonly property string folderPath: settingsAdapter.folderPath
    readonly property bool isVideo: ["mp4", "webm", "mkv", "mov"].includes(root.path.split(".").pop().toLowerCase())
    readonly property string source: root.path ? (root._resolvePath(root.path).startsWith("/") ? "file://" + root._resolvePath(root.path) : root.path) : ""
    property var images: []
    property var thumbnailQueue: []
    property var readyThumbnails: ({})

    function _resolvePath(path) {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    function setPath(path) {
        const next = String(path || "").trim();
        if (!next) return false;
        settingsAdapter.path = next;
        settingsFile.writeAdapter();
        WallpaperPlayback.apply(next, false);
        if (Themes.mode === "dynamic") Themes.applyDynamic();
        return true;
    }

    function setFolder(path) {
        settingsAdapter.folderPath = String(path || "").trim();
        settingsFile.writeAdapter();
        root.scanFolder();
    }

    function scanFolder() {
        if (!root.folderPath) { root.images = []; return; }
        scanner.command = ["sh", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.avif" -o -iname "*.jxl" -o -iname "*.tiff" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \\) 2>/dev/null | sort',
            "sh", root._resolvePath(root.folderPath)];
        scanner.running = false;
        scanner.running = true;
    }

    function requestThumbnail(sourcePath, outputPath) {
        if (root.readyThumbnails[outputPath] || thumbnailer.outputPath === outputPath
                || root.thumbnailQueue.some(job => job.outputPath === outputPath)) return;
        root.thumbnailQueue = root.thumbnailQueue.concat([{ sourcePath: sourcePath, outputPath: outputPath }]);
        root._startThumbnail();
    }

    function _startThumbnail() {
        if (thumbnailer.running || root.thumbnailQueue.length === 0) return;
        const job = root.thumbnailQueue[0];
        root.thumbnailQueue = root.thumbnailQueue.slice(1);
        thumbnailer.outputPath = job.outputPath;
        thumbnailer.command = ["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && { [ -f \"$2\" ] || ffmpeg -y -loglevel error -ss 00:00:00.5 -i \"$1\" -frames:v 1 -vf scale=320:-1 \"$2\"; }", "_", job.sourcePath, job.outputPath];
        thumbnailer.running = true;
    }

    property Process scanner: Process {
        stdout: StdioCollector { onStreamFinished: root.images = text.split("\n").filter(line => line.length > 0) }
    }
    property Process thumbnailer: Process {
        property string outputPath: ""
        onExited: exitCode => {
            if (exitCode === 0) root.readyThumbnails = Object.assign({}, root.readyThumbnails, { [outputPath]: true });
            root._startThumbnail();
        }
    }
    property FileView settingsFile: FileView {
        path: Quickshell.statePath("wallpaper.json")
        watchChanges: true
        onLoaded: {
            root.scanFolder();
            if (root.path) WallpaperPlayback.apply(root.path, true);
        }
        JsonAdapter { id: settingsAdapter; property string path: ""; property string folderPath: "" }
    }
}
