import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    Component.onCompleted: {
        try {
            root.verify(Launcher._score({ title: "Firefox" }, "fire") === 3, "prefix score");
            root.verify(Launcher._score({ title: "Firefox" }, "fox") === 2, "substring score");
            const result = Launcher._normalized("window", { address: "0x1", title: "Editor", appClass: "code" }, 4);
            root.verify(result.id === "window:0x1" && result.activation.address === "0x1", "normalized window");
            const rejected = Launcher.activate({ activation: { kind: "unknown" } });
            root.verify(!rejected.accepted && !rejected.close, "failed activation remains open");
            Launcher.search("/em smile");
            root.verify(Launcher.emojiMode, "emoji mode");
            console.warn("LAUNCHER_TEST_PASS");
        } catch (error) {
            console.error("LAUNCHER_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
