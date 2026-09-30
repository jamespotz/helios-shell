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
            root.verify(Config.islandKeys.includes("idleLayout") && Config.islandKeys.includes("gestureScroll"), "island keys cover island options");
            root.verify(!Config.islandKeys.includes("fontFamily") && !Config.islandKeys.includes("reducedMotion"), "global options excluded");

            Config.setOption("idleBumpWidth", 222);
            Config.moveWidget("idle", "clock", 0);
            Config.setDestinationHidden("weather", true);
            const text = Config._islandPreset();
            const parsed = JSON.parse(text);
            root.verify(parsed.helios === "island" && parsed.version === 1, "header");
            root.verify(!("fontFamily" in parsed.options), "global option not exported");

            Config.resetOptions(Config.islandKeys);
            root.verify(Config.idleBumpWidth === 140 && Config.idleWidgetLayout[0] !== "clock", "reset all");

            root.verify(Config._applyIslandPreset(text) === Config.islandKeys.length, "applies every key");
            root.verify(Config.idleBumpWidth === 222 && Config.idleWidgetLayout[0] === "clock" && Config.destinationHidden("weather"), "round trip");

            root.verify(Config._applyIslandPreset("hello") === -1, "non-JSON rejected");
            root.verify(Config._applyIslandPreset(JSON.stringify({ helios: "island", version: 1, options: null })) === -1, "null options rejected");
            root.verify(Config._applyIslandPreset(JSON.stringify({ helios: "island", version: 1, options: [] })) === -1, "array options rejected");
            root.verify(Config._applyIslandPreset(JSON.stringify({ helios: "dock", version: 1, options: {} })) === -1, "wrong header rejected");
            const n = Config._applyIslandPreset(JSON.stringify({ helios: "island", version: 1,
                options: { bogus: 1, idleBumpWidth: "wide", hiddenDestinations: "all", notifyWidth: 5000, fontFamily: "Comic" } }));
            root.verify(n === 1 && Config.notifyWidth === 600, "only valid island keys applied, clamped");
            root.verify(Config.idleBumpWidth === 222 && Array.isArray(Config.hiddenDestinations) && Config.fontFamily === "Inter", "invalid values ignored");

            Config.resetOptions(Config.islandKeys);
            console.warn("ISLAND_PRESET_TEST_PASS");
        } catch (error) {
            console.error("ISLAND_PRESET_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
