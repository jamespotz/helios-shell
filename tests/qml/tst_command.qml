import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function fail(error) { console.error("COMMAND_TEST_FAIL:", error.toString()); root.terminateDelay.start(); }

    property var results: []
    // Each case runs after the previous one reports.
    readonly property var cases: [
        { command: ["sh", "-c", "echo '{\"a\": 1}'"], parse: "json",
          check: r => r.exitCode === 0 && r.output.a === 1 && r.error === "" },
        { command: ["sh", "-c", "echo 'not json'"], parse: "json",
          check: r => r.exitCode === 0 && r.output === undefined && r.error === "Unreadable output" },
        { command: ["sh", "-c", "echo one >&2; echo two >&2; exit 3"], parse: "text",
          check: r => r.exitCode === 3 && r.stderr === "one two" && r.error === "one two" },
        { command: ["sh", "-c", "exit 4"], parse: "text",
          check: r => r.error === "Exited with code 4" },
        { command: ["sh", "-c", "printf 'plain'"], parse: "text",
          check: r => r.output === "plain" && r.error === "" }
    ]
    property int index: 0

    Command {
        id: command
        onFinished: result => {
            try {
                root.verify(root.cases[root.index].check(result), "case " + root.index + ": " + JSON.stringify(result));
                root.index++;
                if (root.index < root.cases.length) root.runCase();
                else output.checkExists("/nonexistent/helios-test-file");
            } catch (error) { root.fail(error); }
        }
    }
    function runCase() {
        command.parse = root.cases[root.index].parse;
        command.run(root.cases[root.index].command);
    }

    CaptureOutput {
        id: output
        onMissing: path => {
            try {
                root.verify(path === "/nonexistent/helios-test-file", "missing reports its path");
                console.warn("COMMAND_TEST_PASS");
                root.terminateDelay.start();
            } catch (error) { root.fail(error); }
        }
    }

    Component.onCompleted: root.runCase()
}
