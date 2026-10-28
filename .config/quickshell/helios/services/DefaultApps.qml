pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// xdg-mime/xdg-utils wrapper — Quickshell has no default-app API of its own,
// mime associations are exactly what xdg-mime already owns, so this just
// shells out to it like Avatar.qml does for zenity.
QtObject {
    id: root

    // The first mime of each category is the one queried; setting a default
    // claims all of them.
    readonly property var categories: [
        { id: "browser", label: "Web Browser", icon: "public", mimes: ["x-scheme-handler/http", "x-scheme-handler/https"] },
        { id: "email", label: "Email", icon: "mail", mimes: ["x-scheme-handler/mailto"] },
        { id: "filemanager", label: "File Manager", icon: "folder", mimes: ["inode/directory"] },
        // No mime type for terminals, so this one lives in Config.terminal.
        { id: "terminal", label: "Terminal", icon: "terminal", mimes: [], appCategory: "TerminalEmulator" },
        { id: "editor", label: "Text Editor", icon: "edit_note", mimes: ["text/plain"] },
        { id: "image", label: "Image Viewer", icon: "image", mimes: ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp"] },
        { id: "video", label: "Video Player", icon: "movie", mimes: ["video/mp4", "video/x-matroska", "video/webm", "video/quicktime", "video/x-msvideo"] },
        { id: "music", label: "Music Player", icon: "music_note", mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/wav", "audio/x-wav", "audio/mp4"] },
        { id: "pdf", label: "PDF Viewer", icon: "picture_as_pdf", mimes: ["application/pdf"] },
        { id: "archive", label: "Archive Manager", icon: "folder_zip", mimes: ["application/zip", "application/x-tar", "application/x-compressed-tar", "application/gzip", "application/x-7z-compressed", "application/x-rar"] },
        { id: "calendar", label: "Calendar", icon: "calendar_month", mimes: ["text/calendar"] },
        { id: "torrent", label: "Torrent Client", icon: "download", mimes: ["x-scheme-handler/magnet", "application/x-bittorrent"] }
    ]

    readonly property var mimeCategories: root.categories.filter(c => c.mimes.length)

    // categoryId -> current default desktop file id (e.g. "firefox.desktop"), "" while unknown
    property var current: ({})
    // categoryId -> desktop file ids registered for its first mime, [] while unknown
    property var handlers: ({})

    function refresh() { query.running = true; }

    function setDefault(categoryId, desktopId) {
        const category = root.categories.find(c => c.id === categoryId);
        if (!category) return;
        if (category.id === "terminal") {
            const entry = DesktopEntries.byId(desktopId.replace(/\.desktop$/, ""));
            if (entry && entry.command.length && Config.setOption("terminal", entry.command[0]))
                CustomCommands.rewrite();
            return;
        }
        setProc.command = ["xdg-mime", "default", desktopId].concat(category.mimes);
        setProc.running = true;
    }

    // One line per mime category: the default, then each registered handler, tab-separated.
    property Process query: Process {
        command: ["sh", "-c", "for m; do xdg-mime query default \"$m\" | tr -d '\\n'; "
            + "gio mime \"$m\" 2>/dev/null | sed -n 's/^\\t/\\t/p' | tr -d '\\n'; echo; done",
            "_"].concat(root.mimeCategories.map(c => c.mimes[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                const current = {};
                const handlers = {};
                root.mimeCategories.forEach((c, i) => {
                    const fields = (lines[i] || "").split("\t");
                    current[c.id] = fields[0].trim();
                    handlers[c.id] = [...new Set(fields.slice(1).filter(f => f))];
                });
                root.current = current;
                root.handlers = handlers;
            }
        }
    }

    property Process setProc: Process {
        onExited: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
