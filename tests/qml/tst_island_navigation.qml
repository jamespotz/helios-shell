import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    Item {
        id: pendingSaveCanvas
        function saveToFile(path, onCaptured, onSaved) { onCaptured(); }
    }

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
        console.assert(IslandNavigation.dismissesOnFocusLoss("screen-a"), "regular destination dismisses on focus loss");
        console.assert(IslandNavigation.toggle("screen-a", "calendar"), "same destination toggles closed");
        console.assert(!IslandNavigation.open, "toggle closes");
        console.assert(IslandNavigation.modeFor("screen-a", false) === "idle", "idle is fallback state");
        console.assert(IslandNavigation.modeFor("screen-a", true) === "peek", "hover selects peek state");
        console.assert(IslandNavigation.select("volume"), "select accepts known destination");
        console.assert(!IslandNavigation.select("missing"), "select rejects unknown destination");
        console.assert(IslandNavigation.destinationId === "volume", "rejection preserves destination");
        console.assert(IslandNavigation.show("screen-a", "annotate"), "annotation destination opens");
        console.assert(!IslandNavigation.dismissesOnFocusLoss("screen-a"), "annotation survives canvas focus");
        console.assert(AnnotateState.beginScreenshot("screen-a", "/tmp/capture.png"), "screenshot annotation opens");
        console.assert(AnnotateState.editingScreenshot, "tracks screenshot edit mode");
        console.assert(AnnotateState.screenshotPath === "/tmp/capture.png", "tracks screenshot path");
        AnnotateState.cancelScreenshot();
        console.assert(!AnnotateState.editingScreenshot, "cancel clears screenshot edit mode");
        console.assert(IslandNavigation.destinationId === "screenshot", "cancel returns to screenshot destination");
        console.assert(AnnotateState.beginScreenshot("screen-a", "/tmp/stale-capture.png"), "second screenshot annotation opens");
        IslandNavigation.close();
        AnnotateState.toggle();
        const liveAnnotationIsClean = !AnnotateState.editingScreenshot && AnnotateState.screenshotPath === "";
        IslandNavigation.close();
        AnnotateState.canvas = pendingSaveCanvas;
        AnnotateState.beginScreenshot("screen-a", "/tmp/pending-save.png");
        AnnotateState.saveScreenshot();
        const saveHidesOverlay = AnnotateState.savingScreenshot && !AnnotateState.overlayVisible;
        AnnotateState.cancelScreenshot();
        AnnotateState.canvas = null;
        console.assert(IslandNavigation.show("screen-a", "colorpicker"), "color picker destination opens");
        console.assert(!IslandNavigation.dismissesOnFocusLoss("screen-a"), "color picker survives eyedropper focus");
        console.assert(IslandNavigation.show("screen-a", "calendar"), "switches from retained to regular destination");
        console.assert(IslandNavigation.dismissesOnFocusLoss("screen-a"), "regular destination restores focus-loss dismissal");
        if (liveAnnotationIsClean && saveHidesOverlay)
            console.warn("ISLAND_NAVIGATION_TEST_PASS");
        else
            console.error("ISLAND_NAVIGATION_TEST_FAIL stale screenshot background");
        root.terminateDelay.start();
    }
}
