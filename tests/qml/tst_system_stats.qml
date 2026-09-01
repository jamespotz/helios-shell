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

    SystemMonitorCore { id: monitor }

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
        root.verify(monitor.ingest(JSON.stringify(sample)));
        root.compare(monitor.state.status, "live");
        root.compare(monitor.state.cpu.usage_percent, 12);
        root.compare(monitor.state.networkRate.receivedKBs, 6);
        root.compare(monitor.state.processes[0].pid, 2);
        root.verify(!monitor.ingest("{broken"));
        root.compare(monitor.state.cpu.usage_percent, 12, "malformed sample replaced last good state");
    }

    function test_rejectsUnknownProcessIntent() {
        root.verify(!SystemStats.actOnProcess(123, "unknown"));
    }

    Component.onCompleted: {
        try {
            root.test_stateIsCoherentBeforeSampling();
            root.test_ingestPublishesOneCoherentSnapshot();
            root.test_rejectsUnknownProcessIntent();
            root.pass();
        } catch (error) {
            root.reportFailure(error);
        }
    }
}
