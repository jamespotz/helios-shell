pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wraps `cliphist` (the user's existing Hyprland clipboard-history daemon —
// this doesn't watch the clipboard itself, cliphist already does that via
// wl-paste in the user's Hyprland config). Each entry's `line` is the raw
// "<id>\t<preview>" cliphist gives us; it has to be handed back to `cliphist
// decode`/`delete` byte-for-byte to identify the entry, so we keep it
// verbatim instead of just the preview text.
QtObject {
    id: root

    property var items: []
    property var favorites: []
    property bool favoriteBusy: false
    property string error: ""
    property var _pendingFavorites: null
    property var _request: ({})
    property string _response: ""

    property FileView favoritesFile: FileView {
        path: Quickshell.statePath("clipboard-favorites.json")
        preload: true
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (Array.isArray(saved)) root.favorites = saved.filter(f => f && typeof f.id === "string" && typeof f.text === "string")
                    .map(f => ({ id: f.id, text: f.text, preview: f.text.split("\n")[0] || qsTr("Blank text") }));
            } catch (e) { }
        }
        onSaved: {
            if (root._pendingFavorites !== null) root.favorites = root._pendingFavorites;
            root._pendingFavorites = null;
            root.favoriteBusy = false;
        }
        onSaveFailed: { root._pendingFavorites = null; root.favoriteBusy = false; root.error = qsTr("Could not save clipboard favorites"); }
    }
    function _saveFavorites(next) {
        root._pendingFavorites = next;
        root.favoriteBusy = true;
        favoritesFile.setText(JSON.stringify(next));
    }
    function pin(line) {
        if (root.favoriteBusy) return false;
        const item = root.items.find(entry => entry.line === line);
        if ((item && item.isImage) || /\[\[ binary data /i.test(line)) { root.error = qsTr("Only text can be pinned"); return false; }
        return root._runFavorite({ action: "decode", line: line });
    }
    function unpin(id) {
        if (root.favoriteBusy) return false;
        root.error = "";
        root._saveFavorites(root.favorites.filter(f => f.id !== id));
        return true;
    }
    function copyFavorite(id) {
        const favorite = root.favorites.find(f => f.id === id);
        return favorite ? root._runFavorite({ action: "copy", text: favorite.text }) : false;
    }
    function _runFavorite(request) {
        if (root.favoriteBusy) return false;
        root.error = "";
        root.favoriteBusy = true;
        root._request = request;
        root._response = "";
        favoriteProcess.stdinEnabled = true;
        favoriteProcess.running = true;
        return true;
    }
    property Process favoriteProcess: Process {
        command: ["python3", Qt.resolvedUrl("clipboard-text.py").toString().replace("file://", "")]
        stdinEnabled: true
        onStarted: { write(JSON.stringify(root._request) + "\n"); stdinEnabled = false; }
        stdout: StdioCollector { onStreamFinished: root._response = text }
        onExited: (exitCode, exitStatus) => {
            try {
                const result = JSON.parse(root._response);
                if (exitCode !== 0 || !result.ok) throw new Error(result.error || qsTr("Clipboard operation failed"));
                if (root._request.action === "decode" && !root.favorites.some(f => f.text === result.text)) {
                    root._saveFavorites(root.favorites.concat([{ id: "favorite-" + Date.now(), text: result.text, preview: result.text.split("\n")[0] || qsTr("Blank text") }]));
                    return;
                }
            } catch (e) { root.error = qsTr("Clipboard operation failed: %1").arg(e.message); }
            root.favoriteBusy = false;
        }
    }

    // Ids whose thumbnail has already been decoded to disk this session —
    // ListView recycles/recreates delegates on scroll, and each delegate
    // used to unconditionally spawn its own "decode if missing" shell
    // process on creation; for an already-decoded image that's a wasted
    // fork+exec every time it scrolls back into view. Delegates check this
    // first and skip spawning entirely once an id is known-ready.
    property var readyThumbs: ({})
    function markThumbReady(id) {
        root.readyThumbs = Object.assign({}, root.readyThumbs, { [id]: true });
    }

    function refresh() {
        lister.running = false;
        lister.running = true;
    }

    function copy(line) {
        copier.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", line];
        copier.running = false;
        copier.running = true;
    }

    function remove(line) {
        deleter.command = ["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", line];
        deleter.running = false;
        deleter.running = true;
    }

    function clearAll() {
        wiper.running = false;
        wiper.running = true;
    }

    Component.onCompleted: favoritesFile.text()

    property Process lister: Process {
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.length > 0).map(l => {
                    const tab = l.indexOf("\t");
                    const id = tab >= 0 ? l.slice(0, tab) : l;
                    const preview = tab >= 0 ? l.slice(tab + 1) : l;
                    return { line: l, id: id, preview: preview, isImage: /^\[\[ binary data .*(png|jpe?g|gif|bmp|webp)/i.test(preview) };
                });
            }
        }
    }

    property Process copier: Process {}
    property Process deleter: Process { onExited: root.refresh() }
    property Process wiper: Process { command: ["cliphist", "wipe"]; onExited: root.refresh() }
}
