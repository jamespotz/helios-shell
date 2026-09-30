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
            root.verify(Config.motionPreset === "smooth", "defaults match Smooth");

            Config.applyMotionPreset("bouncy");
            const bouncy = Config.motionPresets.bouncy;
            root.verify(Config.islandSpringStiffness === bouncy.stiffness && Config.islandSpringDamping === bouncy.damping, "preset sets island spring");
            root.verify(Config.satelliteSpringStiffness === bouncy.stiffness && Config.satelliteSpringDamping === bouncy.damping, "preset sets satellite spring");
            root.verify(Config.motionPreset === "bouncy", "preset derived from values");

            Config.applyMotionPreset("snappy");
            root.verify(Config.motionPreset === "snappy", "switch preset");

            Config.setOption("satelliteSpringDamping", 2.3);
            root.verify(Config.motionPreset === "custom", "manual change reads as custom");

            Config.applyMotionPreset("bogus");
            root.verify(Config.motionPreset === "custom", "unknown preset ignored");

            Config.resetOptions(Config.motionKeys);
            root.verify(Config.motionPreset === "smooth", "reset returns to Smooth");

            console.warn("ISLAND_MOTION_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_MOTION_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
