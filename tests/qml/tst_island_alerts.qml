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
            root.verify(Config.showTaskAlerts && Config.showMeetingAlerts && Config.showBatteryAlerts, "alert types on by default");
            root.verify(Config.keepCriticalAlerts && !Config.alertSounds, "critical kept, sounds off by default");
            root.verify(Config.batteryAlertThreshold === 20 && Bluetooth.lowBatteryThreshold === 20, "threshold default drives Bluetooth");
            Config.setOption("batteryAlertThreshold", 33);
            root.verify(Config.batteryAlertThreshold === 35 && Bluetooth.lowBatteryThreshold === 35, "threshold steps by 5");
            Config.setOption("batteryAlertThreshold", 90);
            root.verify(Config.batteryAlertThreshold === 50, "threshold clamps");

            Tasks.start("build", "Build");
            root.verify(IslandNavigation.modeFor("DP-1", false) === "idle", "background task leaves the Island idle");
            root.verify(IslandNavigation.satellitesFor("DP-1", true).some(s => s.id === "tasks"), "task appears in right Satellite activities");
            Config.setOption("showTaskAlerts", false);
            root.verify(IslandNavigation.modeFor("DP-1", false) === "idle", "task alert hidden when off");
            root.verify(!IslandNavigation.satellitesFor("DP-1", true).some(s => s.id === "tasks"), "task Satellite honors alert setting");
            root.verify(Tasks.items.length === 1, "task still tracked");
            Config.resetOptions(["showTaskAlerts", "batteryAlertThreshold"]);

            console.warn("ISLAND_ALERTS_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_ALERTS_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
