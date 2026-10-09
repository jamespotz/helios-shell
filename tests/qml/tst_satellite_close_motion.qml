import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI
ShellRoot {
    id: root
    property int samples: 0
    property real maxGapError: 0
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    FloatingWindow {
        visible: true
        width: 1000; height: 800
        Item {
            anchors.fill: parent
            Item { id: anchor; x: 400; y: 20; width: 160; height: 32 }
            IslandUI.IslandSatellite {
                id: satellite
                anchorItem: anchor
                active: true
                badgeWidth: 60
                expandedContent: Component { Item { implicitWidth: 320; implicitHeight: 200 } }
            }
            IslandUI.IslandSatellite {
                id: rightSatellite
                anchorItem: anchor
                onRight: true
                active: true
                expandedContent: Component { Item { implicitWidth: 320; implicitHeight: 200 } }
            }
        }
    }
    Timer {
        interval: 100; running: true
        onTriggered: { Config.setOption("reducedMotion", false); satellite.expanded = false; rightSatellite.expanded = false; sampling.start(); }
    }
    Timer {
        id: sampling; interval: 16; repeat: true
        onTriggered: {
            samples++;
            maxGapError = Math.max(maxGapError, Math.abs(anchor.x - satellite.x - satellite.width - satellite.restGap));
            maxGapError = Math.max(maxGapError, Math.abs(rightSatellite.x - anchor.x - anchor.width - rightSatellite.restGap));
            if (samples * sampling.interval < 1800) return;
            try {
                if (maxGapError > 2) throw new Error("closing loses anchor gap by " + maxGapError.toFixed(1) + "px");
                if (Math.abs(satellite.width - satellite.badgeWidth) > 1) throw new Error("closing still unsettled after spring settles: width " + satellite.width);
                if (Math.abs(rightSatellite.width - rightSatellite.badgeWidth) > 1
                    || Math.abs(satellite.height - satellite.badgeSize) > 1
                    || Math.abs(rightSatellite.height - rightSatellite.badgeSize) > 1)
                    throw new Error("closing size still unsettled after spring settles");
                satellite.active = false;
                rightSatellite.active = false;
                exitCheck.start();
            } catch (e) { console.error("SATELLITE_CLOSE_MOTION_TEST_FAIL:", e.toString()); terminator.running = true; }
            sampling.stop();
        }
    }
    Timer {
        id: exitCheck; interval: 80
        onTriggered: {
            try {
                if (satellite.x + satellite.width <= anchor.x - satellite.restGap + 1
                    || rightSatellite.x >= anchor.x + anchor.width + rightSatellite.restGap - 1)
                    throw new Error("dismissal does not retract toward the Island");
                const leftX = satellite.x;
                const rightX = rightSatellite.x;
                satellite.active = true;
                rightSatellite.active = true;
                if (Math.abs(satellite.x - leftX) > 0.1 || Math.abs(rightSatellite.x - rightX) > 0.1)
                    throw new Error("reopening jumps instead of reversing from current position");
                reversalCheck.start();
            } catch (e) { console.error("SATELLITE_CLOSE_MOTION_TEST_FAIL:", e.toString()); terminator.running = true; }
        }
    }
    Timer {
        id: reversalCheck; interval: 1800
        onTriggered: {
            try {
                if (Math.abs(anchor.x - satellite.x - satellite.width - satellite.restGap) > 1
                    || Math.abs(rightSatellite.x - anchor.x - anchor.width - rightSatellite.restGap) > 1)
                    throw new Error("reversal does not settle beside the Island");
                console.warn("SATELLITE_CLOSE_MOTION_TEST_PASS", "max gap error", maxGapError);
            } catch (e) { console.error("SATELLITE_CLOSE_MOTION_TEST_FAIL:", e.toString()); }
            terminator.running = true;
        }
    }
    Component.onCompleted: { Config.setOption("reducedMotion", true); satellite.expanded = true; rightSatellite.expanded = true; }
}
