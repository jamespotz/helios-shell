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

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            root.verify(IslandNavigation.resolve("calendar").label === "Calendar", "resolves destination metadata");
            root.verify(IslandNavigation.resolve("missing") === null, "rejects unknown destination");
            root.verify(!IslandNavigation.show("screen-a", "missing"), "unknown destination does not open");
            root.verify(IslandNavigation.show("screen-a", "calendar"), "known destination opens");
            root.verify(IslandNavigation.open && IslandNavigation.screen === "screen-a", "tracks target screen");
            root.verify(IslandNavigation.destinationId === "calendar", "tracks destination");
            root.verify(IslandNavigation.panelOpenFor("screen-a"), "resolves screen ownership");
            root.verify(IslandNavigation.modeFor("screen-a", false) === "calendar", "destination has highest priority");
            root.verify(IslandNavigation.expandedFor("screen-a", false), "open destination is expanded");
            root.verify(IslandNavigation.dismissesOnFocusLoss("screen-a"), "regular destination dismisses on focus loss");
            root.verify(IslandNavigation.toggle("screen-a", "calendar"), "same destination toggles closed");
            root.verify(!IslandNavigation.open, "toggle closes");
            root.verify(IslandNavigation.modeFor("screen-a", false) === "idle", "idle is fallback state");
            root.verify(IslandNavigation.modeFor("screen-a", true) === "peek", "hover selects peek state");
            root.verify(IslandNavigation.select("volume"), "select accepts known destination");
            root.verify(!IslandNavigation.select("missing"), "select rejects unknown destination");
            root.verify(IslandNavigation.destinationId === "volume", "rejection preserves destination");
            root.verify(IslandNavigation.show("screen-a", "annotate"), "annotation destination opens");
            root.verify(!IslandNavigation.dismissesOnFocusLoss("screen-a"), "annotation survives canvas focus");
            root.verify(AnnotateState.beginScreenshot("screen-a", "/tmp/capture.png"), "screenshot annotation opens");
            root.verify(AnnotateState.editingScreenshot, "tracks screenshot edit mode");
            root.verify(AnnotateState.screenshotPath === "/tmp/capture.png", "tracks screenshot path");
            AnnotateState.cancelScreenshot();
            root.verify(!AnnotateState.editingScreenshot, "cancel clears screenshot edit mode");
            root.verify(IslandNavigation.destinationId === "screenshot", "cancel returns to screenshot destination");
            root.verify(AnnotateState.beginScreenshot("screen-a", "/tmp/stale-capture.png"), "second screenshot annotation opens");
            IslandNavigation.close();
            Config.setOption("islandLayout", "notch");
            IslandNavigation.toggle("screen-a", "caffeine");
            const notchOpensSatelliteInIsland = IslandNavigation.panelOpenFor("screen-a")
                && IslandNavigation.destinationId === "caffeine" && !IslandNavigation.satelliteOpen;
            IslandNavigation.close();
            Config.setOption("islandLayout", "island");
            IslandNavigation.toggle("screen-a", "caffeine");
            const islandOpensSatelliteBeside = IslandNavigation.satelliteOpenFor("screen-a", "caffeine") && !IslandNavigation.open;
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
            root.verify(IslandNavigation.show("screen-a", "colorpicker"), "color picker destination opens");
            root.verify(!IslandNavigation.dismissesOnFocusLoss("screen-a"), "color picker survives eyedropper focus");
            root.verify(IslandNavigation.show("screen-a", "calendar"), "switches from retained to regular destination");
            root.verify(IslandNavigation.dismissesOnFocusLoss("screen-a"), "regular destination restores focus-loss dismissal");
            root.verify(IslandNavigation.show("screen-a", "screenshot"), "screenshot destination opens");
            Screenshot.captureFullscreen();
            const fullscreenCaptureClosesIsland = !IslandNavigation.open && Screenshot.capturing;
            if (notchOpensSatelliteInIsland && islandOpensSatelliteBeside && liveAnnotationIsClean && saveHidesOverlay && fullscreenCaptureClosesIsland)
                console.warn("ISLAND_NAVIGATION_TEST_PASS");
            else
                console.error("ISLAND_NAVIGATION_TEST_FAIL stale screenshot background");
        } catch (error) { console.error("ISLAND_NAVIGATION_TEST_FAIL:", error.toString()); }
        root.terminateDelay.start();
    }
}
