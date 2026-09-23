import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property TiledLayoutCore tiledLayout: TiledLayoutCore {}

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            const workspaces = JSON.stringify([
                { id: 1, monitor: "DP-1", tiledLayout: "scrolling" },
                { id: 2, monitor: "HDMI-A-1", tiledLayout: "dwindle" }
            ]);

            root.verify(root.tiledLayout.layoutForWorkspace(workspaces, 2) === "dwindle",
                "selects current workspace layout");
            root.verify(root.tiledLayout.layoutForWorkspace("invalid", 1) === "",
                "invalid response has no layout");
            root.verify(root.tiledLayout.iconForLayout("scrolling") === "width_wide",
                "scrolling icon");
            root.verify(root.tiledLayout.iconForLayout("dwindle") === "grid_view",
                "dwindle icon");
            root.verify(root.tiledLayout.iconForLayout("master") === "view_quilt",
                "master icon");
            root.verify(root.tiledLayout.iconForLayout("custom") === "dashboard",
                "unknown layout fallback icon");
            console.warn("TILED_LAYOUT_TEST_PASS");
        } catch (error) {
            console.error("TILED_LAYOUT_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
