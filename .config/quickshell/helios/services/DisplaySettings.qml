pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Display settings service — queries Hyprland for monitor configuration
// and provides controls for resolution, scale, and VRR.
//
// Persistence is handled by display-config.py (modules/bar/): it locates
// the hl.monitor({...}) block for the target output across the user's
// modular hyprland.lua (following both require() and utils.safe_load()),
// edits that field in place, then runs `hyprctl reload` — so changes made
// here survive a Hyprland restart instead of only living in the runtime
// state `hyprctl keyword` would set.
QtObject {
    id: root

    property var monitors: []
    property bool loading: false

    // Populated on demand via queryModes() — the full list of modelines
    // the currently-inspected monitor supports, for the resolution picker.
    property var availableModes: []
    property bool modesLoading: false

    readonly property string _scriptPath: Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/display-config.py"

    function refresh() {
        root.loading = true;
        queryProc.running = false;
        queryProc.running = true;
    }

    function setResolutionMode(monitorName, mode) {
        root._apply(monitorName, ["-m", mode]);
    }

    // Convenience wrapper for callers (Automations.qml's monitor-restore)
    // that have width/height/refreshRate separately rather than a single
    // modeline string.
    function setResolution(monitorName, width, height, refreshRate) {
        root.setResolutionMode(monitorName, width + "x" + height + "@" + Number(refreshRate).toFixed(2) + "Hz");
    }

    function validScales(width, height) {
        const scales = [];
        for (let hundredths = 100; hundredths <= 200; hundredths++) {
            const scale = hundredths / 100;
            const logicalWidth = width / scale;
            const logicalHeight = height / scale;
            if (Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.000001
                    && Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.000001)
                scales.push(scale);
        }
        return scales;
    }

    function setScale(monitorName, scale) {
        root._apply(monitorName, ["-s", String(scale)]);
    }

    function setTransform(monitorName, transform) {
        root._apply(monitorName, ["-t", String(transform)]);
    }

    function setVrr(monitorName, mode) {
        root._apply(monitorName, ["-v", String(mode)]);
    }

    function setHdr(monitorName, enabled) {
        root._apply(monitorName, enabled
            ? ["--cm", "hdr", "--bitdepth", "10"]
            : ["--cm", "srgb"]);
    }

    // Fetches the target monitor's supported modelines into availableModes.
    function queryModes(monitorName) {
        root.modesLoading = true;
        modesProc.command = ["python3", "-u", root._scriptPath, "-o", monitorName, "-q", "--json"];
        modesProc.running = false;
        modesProc.running = true;
    }

    function _apply(monitorName, flags) {
        applyProc.command = ["python3", "-u", root._scriptPath, "-o", monitorName].concat(flags);
        applyProc.running = false;
        applyProc.running = true;
    }

    property Process applyProc: Process {
        stderr: SplitParser { onRead: data => console.warn("[DisplaySettings] apply:", data) }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[DisplaySettings] apply failed, exit", exitCode);
                root.refresh();
                return;
            }
            applyRefreshTimer.restart();
        }
    }

    // hyprctl reload returns before monitor state always reflects VRR changes.
    // Delay the readback so the toggle does not snap back to stale state.
    property Timer applyRefreshTimer: Timer {
        interval: 250
        onTriggered: root.refresh()
    }

    property string _modesOutput: ""

    property Process modesProc: Process {
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._modesOutput += data
        }
        stderr: SplitParser { onRead: data => console.warn("[DisplaySettings] modes:", data) }
        onStarted: root._modesOutput = ""
        onExited: exitCode => {
            root.modesLoading = false;
            if (exitCode !== 0) console.warn("[DisplaySettings] queryModes failed, exit", exitCode);
            if (exitCode === 0 && root._modesOutput.length > 0) {
                try {
                    const info = JSON.parse(root._modesOutput);
                    root.availableModes = info.availableModes || [];
                } catch (e) {
                    root.availableModes = [];
                }
            }
            root._modesOutput = "";
        }
    }

    property string _rawOutput: ""

    property Process queryProc: Process {
        command: ["python3", "-u", root._scriptPath, "--query", "--json", "--all"]
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

    Component.onCompleted: root.refresh()
}
