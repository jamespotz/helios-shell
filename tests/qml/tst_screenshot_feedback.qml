import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 250; onTriggered: root.terminator.running = true }

    Component.onCompleted: {
        Screenshot.lastPath = "/tmp/Screen-20260919-120000.png";
        Screenshot._captureSucceeded();
        root.terminateDelay.start();
    }
}
