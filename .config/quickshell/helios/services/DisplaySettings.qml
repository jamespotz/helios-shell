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

    property var modeStates: ({})

    function modeState(monitorName) {
        return root.modeStates[monitorName] || { modes: [], loading: false };
    }

    readonly property string _scriptPath: Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/display-config.py"

    function refresh() {
        root.loading = true;
        queryProc.running = false;
        queryProc.running = true;
    }

    function setResolutionMode(monitorName, mode) {
        root.applyMonitor(monitorName, { mode: mode });
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
        root.applyMonitor(monitorName, { scale: scale });
    }

    function setTransform(monitorName, transform) {
        root.applyMonitor(monitorName, { transform: transform });
    }

    function setVrr(monitorName, mode) {
        root.applyMonitor(monitorName, { vrr: mode });
    }

    function setHdr(monitorName, enabled) {
        root.applyMonitor(monitorName, enabled
            ? { cm: "hdr", bitdepth: 10 }
            : { cm: "srgb" });
    }

    // Fetches the target monitor's supported modelines into availableModes.
    function queryModes(monitorName) {
        const states = Object.assign({}, root.modeStates);
        states[monitorName] = Object.assign({}, root.modeState(monitorName), { loading: true });
        root.modeStates = states;
        modesProc.monitorName = monitorName;
        modesProc.command = ["python3", "-u", root._scriptPath, "-o", monitorName, "-q", "--json"];
        modesProc.running = false;
        modesProc.running = true;
    }

    property var _pendingChanges: ({})

    function applyMonitor(monitorName, changes) {
        const pending = Object.assign({}, root._pendingChanges);
        pending[monitorName] = Object.assign({}, pending[monitorName] || {}, changes || {});
        root._pendingChanges = pending;
        root._startNextApply();
    }

    function _flags(changes) {
        const flags = [];
        if (changes.mode !== undefined) flags.push("-m", String(changes.mode));
        if (changes.position !== undefined) flags.push("-p", String(changes.position));
        if (changes.scale !== undefined) flags.push("-s", String(changes.scale));
        if (changes.transform !== undefined) flags.push("-t", String(changes.transform));
        if (changes.vrr !== undefined) flags.push("-v", String(changes.vrr));
        if (changes.cm !== undefined) flags.push("--cm", String(changes.cm));
        if (changes.bitdepth !== undefined) flags.push("--bitdepth", String(changes.bitdepth));
        return flags;
    }

    function _startNextApply() {
        if (applyProc.running) return;
        const names = Object.keys(root._pendingChanges);
        if (names.length === 0) return;
        const monitorName = names[0];
        const changes = root._pendingChanges[monitorName];
        const pending = Object.assign({}, root._pendingChanges);
        delete pending[monitorName];
        root._pendingChanges = pending;
        applyProc.command = ["python3", "-u", root._scriptPath, "-o", monitorName].concat(root._flags(changes));
        applyProc.running = true;
    }

    property Process applyProc: Process {
        stderr: SplitParser { onRead: data => console.warn("[DisplaySettings] apply:", data) }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[DisplaySettings] apply failed, exit", exitCode);
                root.refresh();
                root._startNextApply();
                return;
            }
            applyRefreshTimer.restart();
            root._startNextApply();
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
        property string monitorName: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root._modesOutput += data
        }
        stderr: SplitParser { onRead: data => console.warn("[DisplaySettings] modes:", data) }
        onStarted: root._modesOutput = ""
        onExited: exitCode => {
            if (exitCode !== 0) console.warn("[DisplaySettings] queryModes failed, exit", exitCode);
            let modes = [];
            if (exitCode === 0 && root._modesOutput.length > 0) {
                try {
                    const info = JSON.parse(root._modesOutput);
                    modes = info.availableModes || [];
                } catch (e) {}
            }
            const states = Object.assign({}, root.modeStates);
            states[modesProc.monitorName] = { modes: modes, loading: false };
            root.modeStates = states;
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
