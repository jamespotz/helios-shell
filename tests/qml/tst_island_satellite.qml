import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    readonly property Timer completionCheck: Timer {
        interval: 1800
        onTriggered: {
            try {
                root.verify(!Tasks.items.some(t => t.id === "completed"), "completed task expires without opening its Satellite");
                root.verify(Tasks.items.some(t => t.id === "failed"), "failed task stays available until dismissed");
                Tasks.remove("failed");
                IdleInhibit.inhibited = false;
                root.verify(IslandNavigation.satelliteFor("screen-a", true) === null, "empty right slot disappears");
                console.warn("ISLAND_SATELLITE_TEST_PASS");
            } catch (error) { console.error("ISLAND_SATELLITE_TEST_FAIL:", error.toString()); }
            root.terminateDelay.start();
        }
    }

    Component.onCompleted: {
        try {
            IslandNavigation.close();
            root.verify(IslandNavigation.show("screen-a", "calendar"), "Calendar opens");
            root.verify(IslandNavigation.show("screen-a", "maintenance"), "legacy Maintenance opens satellite");
            root.verify(IslandNavigation.panelOpenFor("screen-a"), "Maintenance preserves main Island");
            root.verify(IslandNavigation.destinationId === "calendar", "Maintenance preserves Calendar selection");
            root.verify(IslandNavigation.satelliteOpenFor("screen-a", "maintenance"), "Maintenance opens alongside Calendar");
            root.verify(IslandNavigation.modeFor("screen-a", false) === "calendar", "satellite does not change main mode");
            root.verify(!IslandNavigation.showSatellite("screen-a", "missing"), "unknown satellite rejected");
            root.verify(IslandNavigation.satelliteOpenFor("screen-a", "maintenance"), "rejection preserves satellite");
            root.verify(IslandNavigation.showSatellite("screen-a", "recording"), "recording controls open");
            root.verify(!IslandNavigation.satelliteOpenFor("screen-a", "maintenance"), "second satellite replaces first");
            root.verify(IslandNavigation.panelOpenFor("screen-a"), "replacement preserves main");
            IslandNavigation.closeSatellite("screen-a");
            root.verify(!IslandNavigation.satelliteOpenFor("screen-a"), "targeted satellite close");
            root.verify(IslandNavigation.panelOpenFor("screen-a"), "satellite close preserves Calendar");
            IslandNavigation.showSatellite("screen-a", "maintenance");
            IslandNavigation.closeMain("screen-a");
            root.verify(!IslandNavigation.panelOpenFor("screen-a"), "targeted main close");
            root.verify(IslandNavigation.satelliteOpenFor("screen-a", "maintenance"), "main close preserves satellite");
            IslandNavigation.toggle("screen-a", "maintenance");
            root.verify(!IslandNavigation.satelliteOpenFor("screen-a"), "legacy toggle closes satellite");
            IslandNavigation.show("screen-a", "calendar");
            IslandNavigation.showSatellite("screen-b", "maintenance");
            root.verify(!IslandNavigation.panelOpenFor("screen-a"), "moving satellite releases previous screen focus");
            IslandNavigation.closeSatellite("screen-a");
            root.verify(IslandNavigation.satelliteOpenFor("screen-b"), "wrong screen close is ignored");
            IslandNavigation.show("screen-b", "launcher");
            IslandNavigation.select("maintenance");
            root.verify(!IslandNavigation.panelOpenFor("screen-b"), "Launcher navigation leaves Launcher");
            root.verify(IslandNavigation.satelliteOpenFor("screen-b", "maintenance"), "Launcher selects satellite");
            IslandNavigation.close();
            IslandNavigation.show("screen-a", "calendar");
            IslandNavigation.showSatellite("screen-a", "recording");
            IslandNavigation.dismissOutside("screen-a");
            root.verify(!IslandNavigation.open && !IslandNavigation.satelliteOpen, "outside click dismisses both transient hosts");
            IslandNavigation.show("screen-a", "annotate");
            IslandNavigation.showSatellite("screen-a", "maintenance");
            IslandNavigation.dismissOutside("screen-a");
            root.verify(IslandNavigation.panelOpenFor("screen-a") && !IslandNavigation.satelliteOpen, "outside click preserves retained annotation and closes transient satellite");
            IslandNavigation.close();
            root.verify(!IslandNavigation.open && !IslandNavigation.satelliteOpen, "legacy close releases both hosts");
            Maintenance.infoProc.running = false;
            Maintenance.unitsProc.running = false;
            Maintenance.failedUnits = [];
            Maintenance.firmwareUpdates = [];
            Maintenance.rebootRequired = false;
            Maintenance.flatpakUpdates = 0;
            Maintenance.dnfUpdates = 1;
            Tasks.start("build", "Build");
            FocusModes.activeId = "focus";
            IdleInhibit.inhibited = true;
            root.verify(IslandNavigation.satelliteFor("screen-a", true).id === "tasks", "tasks take priority over maintenance, focus, and caffeine");
            const meetingStart = new Date(Date.now() + 3 * 60000);
            Calendar.upcomingAlert = { date: Qt.formatDateTime(meetingStart, "yyyy-MM-dd"), startTime: Qt.formatDateTime(meetingStart, "HH:mm"), summary: "Standup", links: [] };
            root.verify(IslandNavigation.satelliteFor("screen-a", true).id === "meeting", "upcoming meeting takes priority over tasks");
            root.verify(IslandNavigation.modeFor("screen-a", false) === "idle", "meeting keeps main Island idle");
            Calendar.dismissAlert();
            Tasks.remove("build");
            root.verify(IslandNavigation.satelliteFor("screen-a", true).id === "maintenance", "maintenance wins after task finishes");
            Maintenance.dnfUpdates = 0;
            root.verify(IslandNavigation.satelliteFor("screen-a", true).id === "focus-status", "focus takes priority over caffeine");
            root.verify(IslandNavigation.satellitesFor("screen-a", true).some(s => s.id === "caffeine"), "competing activity remains available");
            root.verify(IslandNavigation.showSatellite("screen-a", "caffeine"), "caffeine controls open");
            root.verify(IslandNavigation.satelliteFor("screen-a", true).id === "caffeine", "expanded activity remains pinned despite priority");
            root.verify(IslandNavigation.satelliteFor("screen-b", true).id === "focus-status", "pin only affects its own screen");
            IslandNavigation.close();
            FocusModes.activeId = "";
            const expiredStart = new Date(Date.now() - 2 * 60000);
            Calendar.upcomingAlert = { date: Qt.formatDateTime(expiredStart, "yyyy-MM-dd"), startTime: Qt.formatDateTime(expiredStart, "HH:mm"), summary: "Expired meeting", links: [] };
            Calendar._scheduleAlert();
            root.verify(Calendar.upcomingAlert === null, "expired meeting does not leave a stale Satellite");
            Tasks.start("completed", "Completed task");
            Tasks.finish("completed", true);
            Tasks.start("failed", "Failed task");
            Tasks.finish("failed", false);
            root.completionCheck.start();
            return;
        } catch (error) { console.error("ISLAND_SATELLITE_TEST_FAIL:", error.toString()); }
        root.terminateDelay.start();
    }
}
