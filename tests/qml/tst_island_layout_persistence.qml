import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property bool writing: Quickshell.env("HELIOS_LAYOUT_TEST_PHASE") === "write"
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function finish(error) {
        if (error) console.error("ISLAND_LAYOUT_PERSISTENCE_TEST_FAIL:", error.toString());
        else console.warn("ISLAND_LAYOUT_PERSISTENCE_TEST_PASS", root.writing ? "write" : "read");
        root.terminateDelay.start();
    }

    Component.onCompleted: {
        Config.settingsFile.blockLoading = true;
        Config.settingsFile.reload();
        root.runTests.start();
    }

    readonly property Timer runTests: Timer {
        interval: 100
        onTriggered: {
            try {
                if (root.writing) {
                    Config.moveWidget("peek", "launcher", 0);
                    Config.moveWidget("idle", "launcher", 0);
                    root.saved.start();
                } else {
                    if (Config.peekWidgetLayout[0] !== "launcher")
                        throw new Error("expanded Island Launcher order reset after restart");
                    if (Config.idleWidgetLayout[0] !== "launcher")
                        throw new Error("idle Island Launcher order reset after restart");
                    root.finish();
                }
            } catch (error) { root.finish(error); }
        }
    }

    // Allow Config's debounced save to complete before ending the process.
    readonly property Timer saved: Timer { interval: 600; onTriggered: root.finish() }
}
