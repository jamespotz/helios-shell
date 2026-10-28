import QtQuick
import Quickshell
import Quickshell.Io

// The output folder and files of a capture (Screenshot, ScreenRecorder):
// opens them, picks a new folder, and notices a file deleted outside the shell.
QtObject {
    id: root

    property string pickTitle: ""
    signal folderPicked(string path)
    signal missing(string path)

    // setsid + redirecting all stdio to /dev/null fully detaches the opened
    // app: otherwise its own children (an image viewer or video player that
    // logs to stdout, LosslessCut) inherit our pipe and die with EPIPE once
    // xdg-open exits and the pipe closes.
    function open(path) {
        if (path) Quickshell.execDetached(["sh", "-c", "setsid xdg-open \"$0\" >/dev/null 2>&1 </dev/null &", path]);
    }

    function pickFolder() { root._picker.run(); }

    // Checked on demand (when the Island reopens) rather than watched.
    function checkExists(path) {
        if (!path) return;
        root._exists.path = path;
        root._exists.run(["test", "-f", path]);
    }

    property Command _picker: Command {
        command: ["zenity", "--file-selection", "--directory", "--title=" + root.pickTitle]
        onFinished: result => { if (result.output.trim()) root.folderPicked(result.output.trim()); }
    }
    property Command _exists: Command {
        property string path: ""
        onFinished: result => { if (result.exitCode !== 0) root.missing(path); }
    }
}
