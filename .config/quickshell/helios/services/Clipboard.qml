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

    Component.onCompleted: root.refresh()
}
