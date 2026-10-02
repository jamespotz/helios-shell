import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root
    readonly property bool writing: Quickshell.env("HELIOS_TURNTABLE_PHASE") === "write"
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer finish: Timer { interval: 600; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    Component.onCompleted: { Config.settingsFile; }
    Timer {
        running: true
        interval: 150
        onTriggered: {
            try {
                root.verify(Config.turntableScale !== undefined, "Turntable preferences available");
                const keys = ["turntableDesign", "turntableScale", "turntableFinish", "turntablePlatter", "turntableArtworkSize", "turntableSpin", "turntableSpeed", "turntableTonearm", "turntableTrackProgress"];
                if (root.writing) {
                    root.verify(Config.turntableDesign === "classic", "existing settings default to Classic design");
                    Config.setOption("turntableDesign", "sleeve");
                    Config.setOption("turntableDesign", "invalid");
                    Config.setOption("turntableScale", 999);
                    Config.setOption("turntableFinish", "charcoal");
                    root.verify(Config.turntablePlatter === "black", "existing settings default to black platter");
                    Config.setOption("turntablePlatter", "aurora");
                    for (const preset of ["ocean", "sunrise", "meadow", "autumn", "forest"]) {
                        Config.setOption("turntablePlatter", preset);
                        root.verify(Config.turntablePlatter === preset, "nature preset accepted: " + preset);
                    }
                    Config.setOption("turntableArtworkSize", 999);
                    Config.setOption("turntableSpin", false);
                    Config.setOption("turntableSpeed", "45");
                    Config.setOption("turntableTonearm", false);
                    Config.setOption("turntableTrackProgress", false);
                    Config.setOption("turntableFinish", "invalid");
                    Config.setOption("turntablePlatter", "invalid");
                    Config.setOption("turntableSpeed", "invalid");
                }
                const actual = keys.map(key => Config[key]);
                root.verify(JSON.stringify(actual) === JSON.stringify(["sleeve", 120, "charcoal", "forest", 72, false, "45", false, false]), "preferences clamp, validate and survive restart: " + JSON.stringify(actual));
                root.verify(keys.every(key => !Config.islandKeys.includes(key)), "Turntable preferences excluded from Island presets");
                console.warn("TURNTABLE_PREFERENCES_TEST_PASS");
            } catch (error) { console.error("TURNTABLE_PREFERENCES_TEST_FAIL", error.toString()); }
            root.finish.start();
        }
    }
}
