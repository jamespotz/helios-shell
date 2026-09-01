pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live CPU/memory/GPU/disk/network stats for modules/bar/SystemMonitorTab.qml,
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
    readonly property SystemMonitorCore _core: SystemMonitorCore {}
    readonly property var state: root._core.state

    signal processKillResult(int pid, bool success, string message)

    function setActive(active) {
        if (active) {
            root._core.setStatus("starting");
            proc.running = true;
        } else {
            proc.running = false;
            root._core.setStatus("stopped");
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
                try { root._core.completeProcessAction(JSON.parse(text)); }
                catch (e) { root._core.completeProcessAction({ pid: killProc.targetPid, success: false, message: "Invalid process result" }); }
            }
        }
        stderr: SplitParser {
            onRead: line => killProc._errBuf += (killProc._errBuf.length > 0 ? " " : "") + line
        }
        onExited: exitCode => {
            const success = exitCode === 0;
            if (!root.state.processAction || root.state.processAction.pid !== killProc.targetPid)
                root._core.completeProcessAction({ pid: killProc.targetPid, success: success, message: success ? "" : (killProc._errBuf || "Failed") });
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
                    if (!root._core.ingest(line)) console.warn("[SystemMonitor] ignoring malformed sample");
            }
        }
    }
}
