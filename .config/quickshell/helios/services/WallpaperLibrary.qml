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
    property bool settingsReady: false
    signal settingsLoaded()

    function _resolvePath(path) {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    function _activeFirst(list, activePath) {
        const active = root._resolvePath(String(activePath || root.path));
        const index = list.findIndex(image => root._resolvePath(image) === active);
        if (index <= 0) return list;
        return [list[index]].concat(list.slice(0, index), list.slice(index + 1));
    }

    function _storedImages() {
        const wallpapers = Array.isArray(settingsAdapter.wallpapers) ? settingsAdapter.wallpapers : [];
        return wallpapers
            .filter(wallpaper => wallpaper && typeof wallpaper.path === "string" && wallpaper.path.length > 0)
            .sort((left, right) => Number(left.sortOrder) - Number(right.sortOrder))
            .map(wallpaper => wallpaper.path);
    }

    function _storeImages(images, forceWrite) {
        const wallpapers = images.map((image, index) => ({
            path: image,
            sortOrder: index
        }));
        if (!forceWrite && JSON.stringify(wallpapers) === JSON.stringify(settingsAdapter.wallpapers))
            return;
        settingsAdapter.wallpapers = wallpapers;
        settingsFile.writeAdapter();
    }

    function _mergeScan(scannedImages) {
        const scanned = new Set(scannedImages);
        const stored = root._storedImages().filter(image => scanned.has(image));
        const known = new Set(stored);
        return stored.concat(scannedImages.filter(image => !known.has(image)));
    }

    function setPath(path) {
        const next = String(path || "").trim();
        if (!next) return false;
        settingsAdapter.path = next;
        root.images = root._activeFirst(root.images, next);
        root._storeImages(root.images, true);
        return true;
    }

    function setFolder(path) {
        settingsAdapter.folderPath = String(path || "").trim();
        settingsAdapter.wallpapers = [];
        settingsFile.writeAdapter();
        root.scanFolder();
    }

    function scanFolder() {
        if (!root.folderPath) { root.images = []; return; }
        scanner.command = ["sh", "-c",
            '[ -d "$1" ] || exit 1; find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.avif" -o -iname "*.jxl" -o -iname "*.tiff" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \\) 2>/dev/null | sort',
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
        property string scanOutput: ""
        onStarted: scanOutput = ""
        stdout: StdioCollector {
            onStreamFinished: scanner.scanOutput = text
        }
        onExited: exitCode => {
            if (exitCode !== 0) return;
            const scannedImages = scanOutput.split("\n").filter(line => line.length > 0);
            root.images = root._activeFirst(root._mergeScan(scannedImages));
            root._storeImages(root.images, false);
            for (const image of root.images) {
                const extension = image.split(".").pop().toLowerCase();
                if (!["mp4", "webm", "mkv", "mov"].includes(extension)) continue;
                const outputPath = Quickshell.env("HOME") + "/.cache/helios/wallpaper-thumbs/"
                    + image.replace(/[^A-Za-z0-9]/g, "_") + ".jpg";
                root.requestThumbnail(image, outputPath);
            }
        }
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
            root.images = root._activeFirst(root._storedImages());
            root.settingsReady = true;
            root.scanFolder();
            root.settingsLoaded();
        }
        JsonAdapter {
            id: settingsAdapter
            property string path: ""
            property string folderPath: ""
            property var wallpapers: []
        }
    }
}
