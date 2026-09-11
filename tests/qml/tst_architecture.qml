import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            root.verify(DisplaySettings._flags({ mode: "preferred", scale: 1.25, vrr: 2 }).join(" ")
                === "-m preferred -s 1.25 -v 2", "display transaction flags");
            root.verify(Wallpaper.path === WallpaperLibrary.path, "wallpaper state proxy");
            root.verify(Calendar.providerLabel("https://outlook.office365.com/feed") === "Outlook Calendar",
                "calendar provider ownership");
            const outcome = Launcher.activate({ activation: { kind: "unknown" } });
            root.verify(!outcome.accepted && !outcome.close, "launcher failure remains open");
            console.warn("ARCHITECTURE_TEST_PASS");
        } catch (error) {
            console.error("ARCHITECTURE_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
