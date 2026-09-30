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
            console.warn("ISLAND_SATELLITE_TEST_PASS");
        } catch (error) { console.error("ISLAND_SATELLITE_TEST_FAIL:", error.toString()); }
        root.terminateDelay.start();
    }
}
