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
            root.verify(Config.idleWidgetLayout.join(",") === "workspaces,tiledLayout,activeWindow,media,clock,weather,tray,clipboard,statusIndicators,|", "idle default keeps today's order, all left");
            root.verify(Config.peekWidgetLayout.join(",") === "workspaces,tiledLayout,activeWindow,|,clock,weather,tray,clipboard,statusIndicators", "peek default matches clusters");

            root.verify(Config._sanitizeLayout("peek", ["clock", "bogus", "|", "clock", "|", "tray"]).join(",")
                === "clock,|,tray,workspaces,tiledLayout,activeWindow,weather,clipboard,statusIndicators", "drops unknown/duplicates, appends missing");
            root.verify(Config._sanitizeLayout("peek", ["clock"]).slice(-1)[0] === "|", "missing marker goes last");
            root.verify(Config._sanitizeLayout("idle", null).length === 10, "bad value falls back to default");
            root.verify(!Config._sanitizeLayout("peek", []).includes("media"), "media is idle-only");

            Config.moveWidget("idle", "clock", 0);
            root.verify(Config.idleWidgetLayout[0] === "clock", "move to front");
            Config.moveWidget("idle", "|", 1);
            root.verify(Config.idleWidgetLayout.slice(0, 3).join(",") === "clock,|,workspaces", "marker moves like a widget");
            Config.moveWidget("idle", "weather", 99);
            root.verify(Config.idleWidgetLayout.slice(-1)[0] === "weather", "move clamps to end");

            root.verify(Config.widgetShown("idle", "clock") === Config.showIdleClock, "idle toggle key");
            root.verify(Config.widgetShown("peek", "statusIndicators") === Config.showStatusIndicators, "peek toggle key");
            root.verify(Config.widgetShown("idle", "|"), "marker always shown");

            Config.resetOptions(["idleLayout"]);
            root.verify(Config.idleWidgetLayout.slice(-1)[0] === "|", "reset restores default");

            console.warn("ISLAND_LAYOUT_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_LAYOUT_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
