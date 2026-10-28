import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    readonly property Connections queryDone: Connections {
        target: DefaultApps
        function onHandlersChanged() { root.run(); }
    }

    function run() {
        try {
            // Every mime category got a line, even ones with no default.
            for (const c of DefaultApps.mimeCategories)
                root.verify(c.id in DefaultApps.current && Array.isArray(DefaultApps.handlers[c.id]), "missing " + c.id);
            root.verify(DefaultApps.current.image === "fake-viewer.desktop", "image default: " + DefaultApps.current.image);
            root.verify(DefaultApps.handlers.image.includes("fake-viewer.desktop"), "image handlers: " + DefaultApps.handlers.image);
            root.verify(Config.terminalExec.join(" ") === "ghostty -e", "terminal exec: " + Config.terminalExec);
            console.warn("DEFAULT_APPS_TEST_PASS");
        } catch (e) {
            console.warn("DEFAULT_APPS_TEST_FAIL " + e.message);
        }
        root.terminateDelay.start();
    }
}
