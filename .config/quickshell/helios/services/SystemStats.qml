pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live CPU/memory/GPU/disk/network stats for modules/bar/SystemMonitorIsland.qml,
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
        cpu: ({ usage_percent: 0, per_core: [], frequency_mhz: 0 }),
        memory: ({ usage_percent: 0, used_gb: 0, total_gb: 0 }),
        disk: ({ read_mb: 0, write_mb: 0 }),
        network: ({ sent_mb: 0, received_mb: 0 }), gpu: null, processes: [],
        networkRate: ({ sentKBs: 0, receivedKBs: 0 }),
        networkSentHistory: [], networkReceivedHistory: [], processAction: null
    })

    signal processKillResult(int pid, bool success, string message)

    function setActive(active) {
        if (active) {
            root._setStatus("starting");
            proc.running = true;
        } else {
            proc.running = false;
            root._setStatus("stopped");
        }
    }

    function _processCommand() {
        const base = ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/system-info.py"];
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
        killProc.command = ["python3", "-u", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/system-info.py", "--signal", String(pid), action === "terminate" ? "terminate" : "forceStop"];
        killProc._errBuf = "";
        killProc.running = true;
        return true;
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
        if (!data.cpu || !data.memory || !data.disk || !data.network || !data.network_rate || !data.network_history) return false;
        root.state = {
            status: "live", ready: true,
            cpu: data.cpu, memory: data.memory, disk: data.disk, network: data.network,
            gpu: data.gpu, processes: data.processes || [],
            networkRate: { sentKBs: data.network_rate.sent_kbs, receivedKBs: data.network_rate.received_kbs },
            networkSentHistory: data.network_history.sent_kbs || [],
            networkReceivedHistory: data.network_history.received_kbs || [],
            processAction: root.state.processAction
        };
        return true;
    }
    function _completeProcessAction(result) {
        root.state = Object.assign({}, root.state, { processAction: result });
    }
}
