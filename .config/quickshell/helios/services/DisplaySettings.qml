pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Display settings service — queries Hyprland for monitor configuration
// and provides controls for resolution, refresh rate, scaling, and transform.
QtObject {
    id: root

    property var monitors: []
    property bool loading: false

    function refresh() {
        root.loading = true;
        queryProc.running = false;
        queryProc.running = true;
    }

    function setResolution(monitorName, width, height, refreshRate) {
        const mode = width + "x" + height + "@" + refreshRate;
        applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + "," + mode + ",auto,1"];
        applyProc.running = false;
        applyProc.running = true;
    }

    function setScale(monitorName, scale) {
        applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + ",preferred,auto," + scale];
        applyProc.running = false;
        applyProc.running = true;
    }

    function setTransform(monitorName, transform) {
        applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + ",transform," + transform];
        applyProc.running = false;
        applyProc.running = true;
    }

    function toggleMonitor(monitorName, enabled) {
        if (enabled) {
            applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + ",preferred,auto,1"];
        } else {
            applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + ",disable"];
        }
        applyProc.running = false;
        applyProc.running = true;
    }

    function setVrr(monitorName, mode) {
        // 0 = off, 1 = on, 2 = fullscreen only
        applyProc.command = ["hyprctl", "keyword", "monitor", monitorName + ",vrr," + mode];
        applyProc.running = false;
        applyProc.running = true;
    }

    property string _rawOutput: ""

    property Process queryProc: Process {
        command: ["hyprctl", "monitors", "-j"]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._rawOutput += data
        }
        onStarted: root._rawOutput = ""
        onExited: exitCode => {
            root.loading = false;
            if (exitCode === 0 && root._rawOutput.length > 0) {
                try {
                    root.monitors = JSON.parse(root._rawOutput);
                } catch (e) {
                    root.monitors = [];
                }
            }
            root._rawOutput = "";
        }
    }

    property Process applyProc: Process {
        onExited: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
