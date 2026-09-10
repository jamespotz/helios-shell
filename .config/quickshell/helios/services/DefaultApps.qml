pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// xdg-mime/xdg-utils wrapper — Quickshell has no default-app API of its own,
// mime associations are exactly what xdg-mime already owns, so this just
// shells out to it like Avatar.qml does for zenity.
QtObject {
    id: root

    readonly property var categories: [
        { id: "browser", label: "Web Browser", icon: "public", mimes: ["x-scheme-handler/http", "x-scheme-handler/https"] },
        { id: "filemanager", label: "File Manager", icon: "folder", mimes: ["inode/directory"] },
        { id: "editor", label: "Text Editor", icon: "edit_note", mimes: ["text/plain"] }
    ]

    // categoryId -> current default desktop file id (e.g. "firefox.desktop"), "" while unknown
    property var current: ({ browser: "", filemanager: "", editor: "" })

    function updateCurrent(categoryId, value) {
        const next = Object.assign({}, root.current);
        next[categoryId] = value;
        root.current = next;
    }

    function refresh() {
        browserQuery.running = true;
        filemanagerQuery.running = true;
        editorQuery.running = true;
    }

    function setDefault(categoryId, desktopId) {
        const category = root.categories.find(c => c.id === categoryId);
        if (!category) return;
        setProc.categoryId = categoryId;
        setProc.desktopId = desktopId;
        setProc.command = ["xdg-mime", "default", desktopId].concat(category.mimes);
        setProc.running = true;
    }

    property Process browserQuery: Process {
        command: ["xdg-mime", "query", "default", "x-scheme-handler/http"]
        stdout: StdioCollector { onStreamFinished: root.updateCurrent("browser", text.trim()) }
    }
    property Process filemanagerQuery: Process {
        command: ["xdg-mime", "query", "default", "inode/directory"]
        stdout: StdioCollector { onStreamFinished: root.updateCurrent("filemanager", text.trim()) }
    }
    property Process editorQuery: Process {
        command: ["xdg-mime", "query", "default", "text/plain"]
        stdout: StdioCollector { onStreamFinished: root.updateCurrent("editor", text.trim()) }
    }

    property Process setProc: Process {
        property string categoryId: ""
        property string desktopId: ""
        onExited: root.updateCurrent(categoryId, desktopId)
    }

    Component.onCompleted: root.refresh()
}
