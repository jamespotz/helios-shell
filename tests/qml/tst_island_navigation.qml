import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    Component.onCompleted: {
        console.assert(IslandNavigation.resolve("calendar").label === "Calendar", "resolves destination metadata");
        console.assert(IslandNavigation.resolve("missing") === null, "rejects unknown destination");
        console.assert(!IslandNavigation.show("screen-a", "missing"), "unknown destination does not open");
        console.assert(IslandNavigation.show("screen-a", "calendar"), "known destination opens");
        console.assert(IslandNavigation.open && IslandNavigation.screen === "screen-a", "tracks target screen");
        console.assert(IslandNavigation.destinationId === "calendar", "tracks destination");
        console.assert(IslandNavigation.panelOpenFor("screen-a"), "resolves screen ownership");
        console.assert(IslandNavigation.modeFor("screen-a", false) === "calendar", "destination has highest priority");
        console.assert(IslandNavigation.expandedFor("screen-a", false), "open destination is expanded");
        console.assert(IslandNavigation.toggle("screen-a", "calendar"), "same destination toggles closed");
        console.assert(!IslandNavigation.open, "toggle closes");
        console.assert(IslandNavigation.modeFor("screen-a", false) === "idle", "idle is fallback state");
        console.assert(IslandNavigation.modeFor("screen-a", true) === "peek", "hover selects peek state");
        console.assert(IslandNavigation.select("volume"), "select accepts known destination");
        console.assert(!IslandNavigation.select("missing"), "select rejects unknown destination");
        console.assert(IslandNavigation.destinationId === "volume", "rejection preserves destination");
        console.warn("ISLAND_NAVIGATION_TEST_PASS");
        root.terminateDelay.start();
    }
}
