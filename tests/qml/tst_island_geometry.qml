import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }

    IslandUI.IslandGeometry { id: g; surfaceWidth: 2000; screenHeight: 1200 }
    // No destination: its implicitHeight is the host's chrome alone.
    IslandUI.IslandDestinationHost { id: emptyHost; destinationId: ""; targetScreen: "" }

    Component.onCompleted: {
        try {
            Config.setOption("reducedMotion", true);
            const gap = Config.islandTopGap;
            root.verify(g.hitTop === gap && g.hitWidth === Config.idleBumpWidth && g.hitHeight === Config.idleBumpHeight,
                "idle Island sits below the top gap at the idle size");
            root.verify(g.padH === 0 && g.padV === 0, "idle has no content padding");
            root.verify(g.exclusiveZone === Config.islandExclusiveZone + Config.islandWindowGap, "Island reserves bump plus gap");
            root.verify(g.surfaceHeight === gap + Math.min(Config.islandMaxHeight, 1200 - gap), "surface fits the screen");

            g.contentReady = true; g.contentWidth = 300; g.contentHeight = 40;
            g.mode = "calendar"; g.expanded = true;
            const w = 300 + Config.islandContentPadH * 2;
            root.verify(g.hitWidth === w && g.paintTargetWidth === w, "open content sizes hit area and shape alike");

            g.contentReady = false;
            root.verify(g.hitWidth === g.maxWidth && g.hitHeight === g.maxHeight, "fresh open: hit area falls back to full size");
            root.verify(g.paintTargetWidth !== g.maxWidth, "fresh open: shape does not balloon to full size");

            g.contentWidth = 5000; g.contentReady = true;
            root.verify(g.hitWidth === g.maxWidth && g.maxWidth <= 2000, "content clamps to the surface");

            root.verify(emptyHost.implicitHeight > 0 && emptyHost.implicitHeight <= g.destinationChrome,
                "destination host chrome (" + emptyHost.implicitHeight + "px) fits the reserved room");
            const room = g.destinationMaxHeight;
            g.satelliteBelow = true;
            root.verify(g.destinationMaxHeight < room, "a satellite below takes room from the destination");
            root.verify(g.satelliteMaxHeight(true, 10) < g.satelliteMaxHeight(false, 10), "below halves satellite room");

            g.paintedWidth = 400;
            root.verify(g.paintedLeft === 800 && g.paintedRight === 1200, "painted edges are centred in the surface");

            g.mode = "idle"; g.expanded = false; g.satelliteBelow = false; g.contentWidth = 100;
            Config.setOption("islandLayout", "zen");
            root.verify(g.zenHidden && g.hitTop === 0 && g.hitHeight === 4, "zen idle leaves a 4px strip at the edge");
            root.verify(g.exclusiveZone === Config.islandWindowGap, "zen reserves only the window gap");
            g.mode = "peek";
            root.verify(!g.zenHidden && g.hitTop === Config.islandTopGap, "zen peek comes down to the top gap");

            g.mode = "idle";
            Config.setOption("islandLayout", "notch");
            root.verify(g.hitTop === 0 && !g.zenHidden, "notch sits on the edge");
            root.verify(g.exclusiveZone === Config.islandExclusiveZone + Config.islandWindowGap, "notch reserves bump plus gap");

            Config.resetOptions(["islandLayout", "reducedMotion"]);
            console.warn("ISLAND_GEOMETRY_TEST_PASS");
        } catch (error) { console.error("ISLAND_GEOMETRY_TEST_FAIL:", error.toString()); }
        root.terminateDelay.start();
    }
}
