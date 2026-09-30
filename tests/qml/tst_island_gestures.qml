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
            let r = IslandGestures._accumulate(0, 60);
            root.verify(r.steps === 0 && r.rest === 60, "half notch waits");
            r = IslandGestures._accumulate(r.rest, 60);
            root.verify(r.steps === 1 && r.rest === 0, "two halves make a notch");
            r = IslandGestures._accumulate(0, -250);
            root.verify(r.steps === -2 && r.rest === -10, "fast scroll down keeps remainder");

            root.verify(!IslandGestures.overFullscreen("hidden", true, "notify"), "hidden never lifts");
            root.verify(IslandGestures.overFullscreen("alerts", true, "notify"), "alerts lifts alert card");
            root.verify(IslandGestures.overFullscreen("alerts", true, "launcher"), "alerts lifts open panel");
            root.verify(!IslandGestures.overFullscreen("alerts", true, "idle"), "idle pill stays hidden");
            root.verify(!IslandGestures.overFullscreen("alerts", true, "peek"), "hover row stays hidden");
            root.verify(!IslandGestures.overFullscreen("alerts", false, "notify"), "no fullscreen, no lift");

            root.verify(Config.islandOverFullscreen === "hidden", "fullscreen default");
            root.verify(Config.gestureScroll === "volume" && Config.gestureMiddleClick === "playpause" && Config.gestureRightClick === "off", "gesture defaults");
            Config.setOption("gestureScroll", "zoom");
            root.verify(Config.gestureScroll === "volume", "unknown scroll action ignored");
            Config.setOption("gestureRightClick", "launcher");
            root.verify(Config.gestureRightClick === "launcher", "right-click destination set");
            Config.setOption("islandOverFullscreen", "alerts");
            root.verify(Config.islandOverFullscreen === "alerts", "fullscreen option set");
            root.verify(Config.options.gestureRightClick.choices.every(c => c === "off" || IslandNavigation.resolve(c)), "right-click choices are real destinations");

            console.warn("ISLAND_GESTURES_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_GESTURES_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
