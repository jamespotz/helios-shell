import QtQuick
import Quickshell.Io

// A Process that reports once, on exit: finished({ exitCode, output, stderr,
// error }). output is stdout's text, or with parse: "json" the parsed value
// (undefined when it doesn't parse). stderr is trimmed, lines joined by
// spaces. error is "" on success, else stderr, the parse failure, or the
// exit code. run() restarts a running command. Quickshell finishes both
// streams before `exited`, so their text is complete here. A command that
// can't start (not installed) reports nothing, same as a bare Process.
Process {
    id: root

    property string parse: "text"
    signal finished(var result)

    function run(command) {
        if (command) root.command = command;
        root.running = false;
        root.running = true;
    }

    stdout: StdioCollector { id: out }
    stderr: StdioCollector { id: err }

    onExited: exitCode => {
        const stderr = err.text.trim().split("\n").join(" ");
        let output = out.text, parseError = "";
        if (root.parse === "json") {
            try { output = JSON.parse(out.text); }
            catch (e) { output = undefined; parseError = "Unreadable output"; }
        }
        root.finished({ exitCode: exitCode, output: output, stderr: stderr,
            error: exitCode !== 0 ? (stderr || "Exited with code " + exitCode) : parseError });
    }
}
