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
            const on = (screen, setting, focused) => IslandNavigation._alertsOn(screen, setting, focused, ["DP-1", "HDMI-A-1"]);
            root.verify(on("DP-1", "all", "") && on("HDMI-A-1", "all", ""), "all screens");
            root.verify(on("HDMI-A-1", "focused", "HDMI-A-1") && !on("DP-1", "focused", "HDMI-A-1"), "focused screen only");
            root.verify(on("DP-1", "focused", "") && on("DP-1", "focused", "DP-9"), "unresolved focus falls back to all");
            root.verify(on("DP-1", "DP-1", "") && !on("HDMI-A-1", "DP-1", ""), "named screen only");
            root.verify(on("HDMI-A-1", "DP-2", ""), "missing named screen falls back to all");

            root.verify(Config.alertScreen === "all", "default all");
            Config.setOption("alertScreen", "HDMI-A-1");
            root.verify(Config.alertScreen === "HDMI-A-1", "screen name stored");

            Tasks.start("sync", "Sync");
            const names = Quickshell.screens.map(s => s.name);
            const here = names[0];
            Config.setOption("alertScreen", here);
            root.verify(IslandNavigation.satellitesFor(here, true).some(s => s.id === "tasks"), "task Satellite on chosen screen");
            root.verify(!IslandNavigation.satellitesFor("elsewhere", true).some(s => s.id === "tasks"), "task Satellite stays off other screens");
            root.verify(IslandNavigation.modeFor(here, false) === "idle", "task keeps chosen Island free");
            root.verify(IslandNavigation.modeFor("elsewhere", false) === "idle", "other screens stay idle");
            root.verify(IslandNavigation.modeFor("elsewhere", true) === "peek", "other screens still hover");
            Config.resetOptions(["alertScreen"]);
            root.verify(IslandNavigation.satellitesFor("elsewhere", true).some(s => s.id === "tasks"), "task Satellite on all screens after reset");

            console.warn("ALERT_SCREEN_TEST_PASS");
        } catch (error) {
            console.error("ALERT_SCREEN_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
