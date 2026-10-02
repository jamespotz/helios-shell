import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    property bool captured: false
    TestCase { id: input; name: "SatelliteActivities"; when: false }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, text, action) {
        if ((item.text === text || item.label === text) && (!action || item.clicked)) return item;
        for (const child of item.children || []) {
            const result = root.find(child, text, action);
            if (result) return result;
        }
        return null;
    }
    function press(text) {
        const button = root.find(surface, text, true);
        root.verify(button && button.enabled, "action available: " + text);
        button.forceActiveFocus();
        input.keyClick(Qt.Key_Space);
    }
    FloatingWindow {
        visible: true
        implicitWidth: 1000
        implicitHeight: 800
        Item {
            id: surface
            anchors.fill: parent
            Item { id: anchor; x: 420; y: 24; width: 200; height: 32 }
            IslandUI.IslandSatelliteHost {
                id: left
                anchorItem: anchor
                definition: IslandNavigation.satelliteFor("test-screen", false)
                targetScreen: "test-screen"
            }
            IslandUI.IslandSatelliteHost {
                id: right
                slotOnRight: true
                anchorItem: anchor
                definition: IslandNavigation.satelliteFor("test-screen", true)
                targetScreen: "test-screen"
            }
        }
    }
    Timer {
        id: advance
        interval: 100
        onTriggered: {
            const directory = Quickshell.env("HELIOS_SATELLITE_CAPTURE_DIR");
            const name = ["privacy", "", "tasks", "meeting", "focus", "caffeine"][root.phase];
            if (directory && name && !root.captured) {
                (root.phase === 0 ? left : right).grabToImage(result => {
                    result.saveToFile(directory + "/" + name + ".png");
                    root.captured = true;
                    advance.restart();
                });
                return;
            }
            root.captured = false;
            try {
                switch (root.phase) {
                case 0:
                    root.verify(root.find(left, "In use by Discord", false) && root.find(left, "In use by Firefox", false), "Privacy shows both capturing apps");
                    ScreenRecorder.recording = true;
                    root.verify(left.activityId === "privacy-status", "open Privacy stays pinned while recording starts");
                    root.press("Other activity");
                    root.press("Recording");
                    break;
                case 1:
                    root.verify(root.find(left, "Stop recording", true), "other activity switches to recording controls");
                    root.verify(IslandNavigation.destinationId === "calendar" && IslandNavigation.panelOpenFor("test-screen"), "Satellite switching preserves main destination");
                    IslandNavigation.closeSatellite();
                    ScreenRecorder.recording = false;
                    MicActivity.isSystemMicActive = false;
                    CameraActivity.isSystemCameraActive = false;
                    root.verify(left.definition === null, "Privacy disappears after apps release devices");
                    IslandNavigation.showSatellite("test-screen", "tasks");
                    break;
                case 2:
                    root.verify(root.find(right, "Build", false) && root.find(right, "Sync", false), "Tasks shows all activity labels");
                    root.verify(root.find(right, "25%", false) && root.find(right, "60%", false), "Tasks shows each task's progress");
                    root.press("Other activity");
                    root.press("Upcoming meeting");
                    break;
                case 3:
                    root.verify(root.find(right, "Standup", false) && root.find(right, "Join meeting", true), "Meeting shows details and join action");
                    root.press("Dismiss reminder");
                    root.verify(Calendar.upcomingAlert === null, "Meeting dismiss acts on Calendar");
                    IslandNavigation.showSatellite("test-screen", "focus-status");
                    break;
                case 4:
                    root.press("Writing");
                    root.verify(FocusModes.activeId === "writing", "Focus changes preset through existing service");
                    root.press("End focus mode");
                    root.verify(FocusModes.activeId === "" && FocusModes.endCalls === 1, "Focus ends through existing service");
                    IslandNavigation.showSatellite("test-screen", "caffeine");
                    break;
                case 5:
                    root.press("Turn off caffeine");
                    root.verify(!IdleInhibit.inhibited && IdleInhibit.toggleCalls === 1, "Caffeine restores idle handling through existing service");
                    IslandNavigation.closeSatellite();
                    root.verify(right.activityId === "tasks", "finishing selected activity restores next priority");
                    Tasks.remove("build");
                    Tasks.remove("sync");
                    root.verify(right.definition === null && right.onRight, "empty right slot keeps its side during disappearance");
                    console.warn("SATELLITE_ACTIVITIES_UI_TEST_PASS");
                    root.terminateDelay.start();
                    return;
                }
                root.phase++;
                advance.restart();
            } catch (error) {
                console.error("SATELLITE_ACTIVITIES_UI_TEST_FAIL:", error.toString());
                root.terminateDelay.start();
            }
        }
    }
    Component.onCompleted: {
        Config.setOption("reducedMotion", true);
        Maintenance.infoProc.running = false;
        Maintenance.unitsProc.running = false;
        Maintenance.dnfUpdates = 0;
        Maintenance.flatpakUpdates = 0;
        Maintenance.rebootRequired = false;
        Maintenance.failedUnits = [];
        Maintenance.firmwareUpdates = [];
        Tasks.start("build", "Build");
        Tasks.progress("build", 0.25, "Build");
        Tasks.start("sync", "Sync");
        Tasks.progress("sync", 0.60, "Sync");
        const start = new Date(Date.now() + 3 * 60000);
        Calendar.upcomingAlert = { date: Qt.formatDateTime(start, "yyyy-MM-dd"), startTime: Qt.formatDateTime(start, "HH:mm"), summary: "Standup", location: "Video call", links: ["https://example.com/meeting"] };
        IslandNavigation.show("test-screen", "calendar");
        IslandNavigation.showSatellite("test-screen", "privacy-status");
        advance.start();
    }
}
