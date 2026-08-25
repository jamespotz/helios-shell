pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Emoji picker data — powers Launcher.qml's "/em <query>" search mode.
// data/emoji.json is vendored from Noctalia (MIT, (c) noctalia-dev):
// [{emoji, name, keywords[], category}, ...].
QtObject {
    id: root

    property var list: []

    function search(query, limit) {
        const q = (query || "").trim().toLowerCase();
        if (!q) return root.list.slice(0, limit);
        const results = [];
        for (const e of root.list) {
            if (results.length >= limit) break;
            if (e.name.toLowerCase().includes(q) || e.category.toLowerCase().includes(q)
                || e.keywords.some(k => k.toLowerCase().includes(q))) {
                results.push(e);
            }
        }
        return results;
    }

    property FileView dataFile: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/helios/data/emoji.json"
        printErrors: false
        preload: true
        blockLoading: true
        onLoaded: {
            try {
                const parsed = JSON.parse(dataFile.text());
                if (Array.isArray(parsed)) root.list = parsed;
            } catch (e) {
                // Missing/corrupt data file — emoji search just comes up empty.
            }
        }
    }
}
