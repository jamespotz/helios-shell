import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root

    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function verify(value, message) { if (!value) throw new Error(message); }

    readonly property FileView legacySettings: FileView {
        path: Quickshell.statePath("island-appearance.json")
        printErrors: false
    }
    Component.onCompleted: {
        root.legacySettings.setText(JSON.stringify({ islandCornerRadius: 27 }));
        root.loadSettings.start();
    }
    readonly property Timer loadSettings: Timer {
        interval: 150
        onTriggered: {
            Config.settingsFile.blockLoading = true;
            Config.settingsFile.reload();
            root.runTests.start();
        }
    }
    readonly property Timer runTests: Timer {
        interval: 150
        onTriggered: root.testPreset()
    }
    function testPreset() {
        try {
            root.verify(Config.islandIdleCornerRadius === 27 && Config.islandExpandedCornerRadius === 27, "legacy saved radius initializes both states");
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
            Config._applyIslandPreset(JSON.stringify({ helios: "island", version: 1, options: { islandCornerRadius: 27 } }));
            root.verify(Config.islandIdleCornerRadius === 27 && Config.islandExpandedCornerRadius === 27, "legacy radius preset initializes both states");
            Config._applyIslandPreset(JSON.stringify({ helios: "island", version: 1,
                options: { islandCornerRadius: 22, islandIdleCornerRadius: 7 } }));
            root.verify(Config.islandIdleCornerRadius === 7 && Config.islandExpandedCornerRadius === 22, "explicit state radius overrides legacy preset");
            Config.resetOptions(Config.islandKeys);
            Config.setOption("islandIdleCornerRadius", 9);
            Config.setOption("islandExpandedCornerRadius", 31);
            Config.settingsFile.writeAdapter();
            root.checkSaved.start();
            return;
        } catch (error) {
            console.error("ISLAND_PRESET_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
    readonly property Timer checkSaved: Timer {
        interval: 150
        onTriggered: {
            try {
                root.legacySettings.blockLoading = true;
                root.legacySettings.reload();
                const saved = JSON.parse(root.legacySettings.text());
                root.verify(saved.islandIdleCornerRadius === 9 && saved.islandExpandedCornerRadius === 31, "independent radii persist to settings file");
                console.warn("ISLAND_PRESET_TEST_PASS");
            } catch (error) {
                console.error("ISLAND_PRESET_TEST_FAIL:", error.toString());
            }
            root.terminateDelay.start();
        }
    }
}
