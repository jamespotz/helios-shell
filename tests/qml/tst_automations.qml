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
            // Fullscreen → DND clears only the DND it set itself.
            ShellState.setDndEnabled(false);
            Automations.fullscreenRule = true;
            Automations._setFullscreen(true);
            root.verify(ShellState.dndEnabled, "fullscreen turns on DND");
            Automations._setFullscreen(false);
            root.verify(!ShellState.dndEnabled, "leaving fullscreen clears its DND");
            ShellState.setDndEnabled(true);
            Automations._setFullscreen(true);
            Automations._setFullscreen(false);
            root.verify(ShellState.dndEnabled, "manual DND survives fullscreen");
            ShellState.setDndEnabled(false);
            Automations.fullscreenRule = false;
            Automations._setFullscreen(true);
            root.verify(!ShellState.dndEnabled, "rule off does nothing");

            console.warn("AUTOMATIONS_TEST_PASS");
        } catch (error) {
            console.error("AUTOMATIONS_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
