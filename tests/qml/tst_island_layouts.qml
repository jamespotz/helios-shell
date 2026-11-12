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
            root.verify(Config.islandLayout === "island" && !Config.islandAttached && !Config.islandAutoHide, "defaults to Island");

            Config.setOption("islandTopGap", 20);
            Config.setOption("showIdleTray", true);

            Config.setOption("islandLayout", "notch");
            root.verify(Config.islandAttached, "notch attaches");
            root.verify(Config.islandTopGap === 0, "notch has no top gap");
            root.verify(Config.islandWindowGap === Config.options.islandTopGap.value, "notch's top gap doesn't move windows");

            Config.setOption("islandLayout", "zen");
            root.verify(Config.islandAutoHide && !Config.islandAttached, "zen hides");
            root.verify(Config.islandTopGap === 20 && Config.islandWindowGap === 20, "leaving notch restores the top gap");

            Config.setOption("islandLayout", "quiet");
            root.verify(!Config.islandAutoHide && !Config.islandAttached, "quiet is a floating Island");
            root.verify(Config.showIdleTray, "layouts never change widget settings");

            Config.setOption("islandLayout", "bogus");
            root.verify(Config.islandLayout === "quiet", "unknown layout rejected");

            Config.resetOptions(["islandLayout", "islandTopGap", "showIdleTray"]);
            root.verify(Config.islandLayout === "island", "reset returns to Island");

            root.verify(Config.screenCornerRadius === 0, "screen corners off by default");
            Config.setOption("screenCornerRadius", 99);
            root.verify(Config.screenCornerRadius === 40, "screen corner radius clamps");
            Config.resetOptions(["screenCornerRadius"]);

            console.warn("ISLAND_LAYOUTS_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_LAYOUTS_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
