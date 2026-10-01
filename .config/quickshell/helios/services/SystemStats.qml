pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live CPU/memory/GPU/disk/network stats for modules/island/SystemMonitorDestination.qml,
// sourced from the user's system-info.py helper (same directory as that tab)
// which polls psutil + nvidia-smi and prints one JSON snapshot per line.
// The Python adapter owns sampling, rates, history, and process safety.
QtObject {
    id: root

    // [{ pid, name, cmdline, user, cpu_percent, memory_percent }], hottest
    // first. Top 6 by default; setFullProcessMode(true) restarts the
    // python helper with --full for the Process List view (all processes,
    // capped at 1000) and back to the cheap top-6 snapshot when it closes.
    property bool fullProcessMode: false
    property var state: ({
        status: "stopped", ready: false,
        cpu: root._withDefaults(null, root._cpuDefaults),
        memory: root._withDefaults(null, root._memoryDefaults),
        disk: ({ read_mb: 0, write_mb: 0 }),
        network: root._withDefaults(null, root._networkDefaults), gpu: null, processes: [],
        storage: null, sensors: root._withDefaults(null, root._sensorDefaults),
        networkRate: ({ sentKBs: 0, receivedKBs: 0 }),
        diskRate: ({ readKBs: 0, writeKBs: 0 }),
        history: ({ cpu: [], memory: [], gpu: [], diskRead: [], diskWrite: [], netSent: [], netReceived: [] }),
        processAction: null
    })

    // Card fields added after the original payload; older or partial
    // samples fall back to these so bindings never see undefined.
    readonly property var _cpuDefaults: ({ usage_percent: 0, per_core: [], frequency_mhz: 0, times: { system: 0, user: 0, idle: 0 } })
    readonly property var _memoryDefaults: ({ usage_percent: 0, used_gb: 0, total_gb: 0, cached_gb: 0, swap_used_gb: 0, swap_total_gb: 0 })
    readonly property var _networkDefaults: ({ sent_mb: 0, received_mb: 0, iface: null, iface_type: null, local_ip: null })
    readonly property var _sensorDefaults: ({ cpu_c: null, fan_rpm: null })

    function _withDefaults(value, defaults) { return Object.assign({}, defaults, value || {}); }

    // First installed disk analyzer / speed test CLI, or "" — detected once
    // per shell session so the cards can hide actions with no backing tool.
    property string diskAnalyzer: ""
    property string speedTestTool: ""
    property bool _toolsDetected: false
    // { running, downMbps, upMbps, error } for the Network card; null until run.
    property var speedTest: null

    signal processKillResult(int pid, bool success, string message)

    function setActive(active) {
        if (active && !root._toolsDetected) {
            root._toolsDetected = true;
            toolProc.running = true;
        }
        if (active) {
            root._setStatus("starting");
            proc.running = true;
        } else {
            proc.running = false;
            root._setStatus("stopped");
        }
    }

    function _processCommand() {
        const base = ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/island/system-info.py"];
        return root.fullProcessMode ? base.concat(["--full"]) : base;
    }

    // Restarts the python helper with/without --full. There's no live IPC
    // channel into the running script, so switching modes means a brief
    // (~one tick) data gap while it respawns — acceptable since this only
    // happens when the Process List view opens/closes, not on a timer.
    function setProcessDetail(full) {
        if (root.fullProcessMode === full) return;
        root.fullProcessMode = full;
        const wasRunning = proc.running;
        if (wasRunning) proc.running = false;
        proc.command = root._processCommand();
        if (wasRunning) proc.running = true;
    }

    // Sends a signal to a pid from the Process List view. Refuses PID 1 as a
    // baseline guardrail; the caller (ProcessListView) additionally refuses
    // to arm the action at all for the shell's own process tree by name.
    function actOnProcess(pid, action) {
        if (killProc.running || (action !== "terminate" && action !== "forceStop")) return false;
        const process = root.state.processes.find(candidate => candidate.pid === pid);
        if (!process || root.isProcessProtected(process)) return false;
        killProc.targetPid = pid;
        killProc.command = ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/island/system-info.py", "--signal", String(pid), action === "terminate" ? "terminate" : "forceStop"];
        killProc._errBuf = "";
        killProc.running = true;
        return true;
    }

    property Process toolProc: Process {
        command: ["sh", "-c", "for tool in baobab filelight qdirstat speedtest speedtest-cli librespeed-cli; do command -v \"$tool\" >/dev/null && echo \"$tool\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(line => line.length > 0);
                root.diskAnalyzer = found.find(tool => ["baobab", "filelight", "qdirstat"].includes(tool)) || "";
                // Open-source CLIs first; Ookla's `speedtest` needs its license
                // accepted interactively once, which the shell won't do for you.
                root.speedTestTool = ["librespeed-cli", "speedtest-cli", "speedtest"].find(tool => found.includes(tool)) || "";
            }
        }
    }

    function runSpeedTest() {
        if (!root.speedTestTool || speedProc.running) return;
        const args = {
            "speedtest": ["speedtest", "--format=json"],
            "speedtest-cli": ["speedtest-cli", "--json"],
            "librespeed-cli": ["librespeed-cli", "--json"]
        };
        speedProc.command = args[root.speedTestTool];
        root.speedTest = { running: true, downMbps: 0, upMbps: 0, error: "" };
        speedProc.running = true;
        speedTimeout.restart();
    }

    // Called when the System monitor closes: a result only means something
    // while you're looking at it, and a test still running is abandoned.
    function clearSpeedTest() {
        speedTimeout.stop();
        speedProc.running = false;
        root.speedTest = null;
    }

    function _speedTestFailed() {
        return root.speedTestTool === "speedtest"
            ? "Run `speedtest` once to accept its license"
            : "Speed test failed";
    }

    property Timer speedTimeout: Timer {
        interval: 90000
        onTriggered: {
            speedProc.running = false;
            root.speedTest = { running: false, downMbps: 0, upMbps: 0, error: "Speed test timed out" };
        }
    }

    // Each CLI reports in its own unit: Ookla bytes/s, speedtest-cli bits/s,
    // librespeed an array already in Mbps.
    function _parseSpeedTest(text) {
        const data = JSON.parse(text);
        if (root.speedTestTool === "speedtest")
            return { down: data.download.bandwidth * 8 / 1e6, up: data.upload.bandwidth * 8 / 1e6 };
        if (root.speedTestTool === "speedtest-cli")
            return { down: data.download / 1e6, up: data.upload / 1e6 };
        const result = Array.isArray(data) ? data[0] : data;
        return { down: result.download, up: result.upload };
    }

    property Process speedProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (!speedTimeout.running) return; // timed out or cleared
                speedTimeout.stop();
                try {
                    const speed = root._parseSpeedTest(text);
                    root.speedTest = { running: false, downMbps: speed.down, upMbps: speed.up, error: "" };
                } catch (e) {
                    root.speedTest = { running: false, downMbps: 0, upMbps: 0, error: root._speedTestFailed() };
                }
            }
        }
    }

    property Process killProc: Process {
        id: killProc
        property int targetPid: -1
        property string _errBuf: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try { root._completeProcessAction(JSON.parse(text)); }
                catch (e) { root._completeProcessAction({ pid: killProc.targetPid, success: false, message: "Invalid process result" }); }
            }
        }
        stderr: SplitParser {
            onRead: line => killProc._errBuf += (killProc._errBuf.length > 0 ? " " : "") + line
        }
        onExited: exitCode => {
            const success = exitCode === 0;
            if (!root.state.processAction || root.state.processAction.pid !== killProc.targetPid)
                root._completeProcessAction({ pid: killProc.targetPid, success: success, message: success ? "" : (killProc._errBuf || "Failed") });
            const message = success ? "" : (root.state.processAction.message || killProc._errBuf || "Failed");
            root.processKillResult(killProc.targetPid, success, message);
        }
    }

    property Process proc: Process {
        // -u: unbuffered stdout — piped (non-tty) stdout is block-buffered by
        // default, so without this the script's prints sit in its internal
        // buffer for a long time before SplitParser ever sees a line.
        command: root._processCommand()
        stdout: SplitParser {
            onRead: line => {
                    if (!root._ingest(line)) console.warn("[SystemMonitor] ignoring malformed sample");
            }
        }
    }

    function isProcessProtected(process) {
        const name = String(process && process.name || "").toLowerCase();
        return !process || process.pid === 1 || name.includes("quickshell") || name.includes("hyprland");
    }

    function queryProcesses(query, mode, sortColumn, sortDirection, currentUser) {
        const needle = String(query || "").trim().toLowerCase();
        const filtered = root.state.processes.filter(process => {
            if (mode === "apps" && !(process.user === currentUser && String(process.cmdline || "").charAt(0) !== "[")) return false;
            if (mode === "system" && process.user !== "root") return false;
            if (mode === "background" && process.cpu_percent >= 0.1) return false;
            return !needle || String(process.name || "").toLowerCase().includes(needle)
                || String(process.cmdline || "").toLowerCase().includes(needle)
                || String(process.pid).includes(needle);
        });
        const column = sortColumn || "cpu_percent";
        const direction = sortDirection || -1;
        return filtered.slice().sort((left, right) => {
            const a = left[column], b = right[column];
            return typeof a === "string"
                ? direction * a.toLowerCase().localeCompare(String(b || "").toLowerCase())
                : direction * ((a || 0) - (b || 0));
        });
    }

    function _setStatus(status) { root.state = Object.assign({}, root.state, { status: status }); }
    function _ingest(line) {
        let data;
        try { data = JSON.parse(line); } catch (error) { return false; }
        if (!data.cpu || !data.memory || !data.disk || !data.network || !data.network_rate || !data.disk_rate || !data.history) return false;
        const history = data.history;
        root.state = {
            status: "live", ready: true,
            cpu: root._withDefaults(data.cpu, root._cpuDefaults),
            memory: root._withDefaults(data.memory, root._memoryDefaults),
            disk: data.disk,
            network: root._withDefaults(data.network, root._networkDefaults),
            storage: data.storage || null,
            sensors: root._withDefaults(data.sensors, root._sensorDefaults),
            gpu: data.gpu, processes: data.processes || [],
            networkRate: { sentKBs: data.network_rate.sent_kbs, receivedKBs: data.network_rate.received_kbs },
            diskRate: { readKBs: data.disk_rate.read_kbs, writeKBs: data.disk_rate.write_kbs },
            history: {
                cpu: history.cpu || [], memory: history.memory || [], gpu: history.gpu || [],
                diskRead: history.disk_read_kbs || [], diskWrite: history.disk_write_kbs || [],
                netSent: history.net_sent_kbs || [], netReceived: history.net_received_kbs || []
            },
            processAction: root.state.processAction
        };
        return true;
    }
    function _completeProcessAction(result) {
        root.state = Object.assign({}, root.state, { processAction: result });
    }
}
