import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process _terminator: Process {
        command: ["sh", "-c", 'kill -TERM "$PPID"']
    }
    readonly property Timer _terminateDelay: Timer {
        interval: 50
        onTriggered: root._terminator.running = true
    }

    function fail(message) { throw new Error(message); }
    function verify(value, message) { if (!value) root.fail(message || "verification failed"); }
    function compare(actual, expected, message) {
        const a = JSON.stringify(actual);
        const e = JSON.stringify(expected);
        if (a !== e) root.fail((message || "values differ") + `: expected ${e}, got ${a}`);
    }
    function pass() {
        console.warn("SYSTEM_STATS_TEST_PASS");
        root._terminateDelay.start();
    }
    function reportFailure(error) {
        console.error("SYSTEM_STATS_TEST_FAIL:", error.toString());
        root._terminateDelay.start();
    }

    readonly property var monitor: SystemStats

    function test_stateIsCoherentBeforeSampling() {
        root.compare(monitor.state.status, "stopped");
        root.compare(monitor.state.ready, false);
        root.compare(monitor.state.processes, []);
        root.compare(monitor.state.networkSentHistory, []);
    }

    function test_ingestPublishesOneCoherentSnapshot() {
        const sample = {
            cpu: { usage_percent: 12, per_core: [12], frequency_mhz: 3000 },
            memory: { usage_percent: 40, used_gb: 4, total_gb: 10 },
            disk: { read_mb: 1, write_mb: 2 }, network: { sent_mb: 3, received_mb: 4 },
            gpu: null, processes: [{ pid: 2, name: "worker" }],
            network_rate: { sent_kbs: 5, received_kbs: 6 },
            network_history: { sent_kbs: [5], received_kbs: [6] }
        };
        root.verify(monitor._ingest(JSON.stringify(sample)));
        root.compare(monitor.state.status, "live");
        root.compare(monitor.state.cpu.usage_percent, 12);
        root.compare(monitor.state.networkRate.receivedKBs, 6);
        root.compare(monitor.state.processes[0].pid, 2);
        root.verify(!monitor._ingest("{broken"));
        root.compare(monitor.state.cpu.usage_percent, 12, "malformed sample replaced last good state");
    }

    function test_rejectsUnknownProcessIntent() {
        root.verify(!SystemStats.actOnProcess(123, "unknown"));
    }

    function test_processQueryAndProtectionStayInsideModule() {
        monitor.state = Object.assign({}, monitor.state, { processes: [
            { pid: 1, name: "systemd", cmdline: "/sbin/init", user: "root", cpu_percent: 0, memory_percent: 0.1 },
            { pid: 22, name: "Editor", cmdline: "code project", user: "tester", cpu_percent: 8, memory_percent: 2 },
            { pid: 23, name: "quickshell", cmdline: "qs", user: "tester", cpu_percent: 2, memory_percent: 1 }
        ] });
        const matches = monitor.queryProcesses("edit", "all", "cpu_percent", -1, "tester");
        root.compare(matches.map(process => process.pid), [22]);
        root.verify(monitor.isProcessProtected(monitor.state.processes[0]), "PID 1 protected");
        root.verify(monitor.isProcessProtected(monitor.state.processes[2]), "shell protected");
        root.verify(!monitor.actOnProcess(23, "terminate"), "protected action rejected");
    }

    Component.onCompleted: {
        try {
            root.test_stateIsCoherentBeforeSampling();
            root.test_ingestPublishesOneCoherentSnapshot();
            root.test_rejectsUnknownProcessIntent();
            root.test_processQueryAndProtectionStayInsideModule();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
