import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/settings" as SettingsUI

ShellRoot {
    id: root
    property int phase: 0
    readonly property var naturePresets: ["Forest", "Ocean", "Sunrise", "Meadow", "Autumn"]
    TestCase { id: input; name: "TurntableSettings"; when: false }
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer finish: Timer { interval: 100; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, name, action) {
        if ((item.objectName === name || item.text === name || item.label === name || (item.modelData && item.modelData.label === name))
            && (!action || item.clicked || item.toggled || item.modelData)) return item;
        for (const child of item.children || []) { const result = root.find(child, name, action); if (result) return result; }
        return null;
    }
    function press(name) {
        const target = root.find(page.item, name, true);
        root.verify(target && target.enabled, "keyboard control available: " + name);
        target.forceActiveFocus(); input.keyClick(Qt.Key_Space);
    }
    FloatingWindow {
        visible: true
        implicitWidth: 540
        implicitHeight: 1060
        color: Colors.background
        Item {
            id: surface
            anchors.fill: parent
            Loader { id: page; x: 20; y: 20; width: 500; sourceComponent: Component { SettingsUI.TurntableSettings {} } }
        }
    }
    Timer {
        id: advance
        interval: 200
        running: true
        onTriggered: {
            try {
                switch (root.phase) {
                case 0:
                    root.verify(page.status === Loader.Ready, "Turntable settings page loads");
                    root.verify(root.find(page.item, "turntablePreview"), "live preview available");
                    root.press("Studio");
                    root.verify(root.find(page.item, "turntablePlatter_black").active, "black platter selected by default");
                    root.press("Sage");
                    root.press("Charcoal"); root.press("45 RPM"); root.press("Record rotation"); root.press("Show tonearm");
                    break;
                case 1:
                    const preview = root.find(page.item, "turntablePreview");
                    root.verify(Config.turntableDesign === "studio" && preview.width > preview.height, "Studio selection updates preview with keyboard");
                    root.press("Minimal");
                    root.verify(Config.turntablePlatter === "sage" && root.find(page.item, "turntablePlatter_sage").active, "solid preset works with keyboard");
                    const gradientChip = root.find(page.item, "turntablePlatter_sunset");
                    input.mouseClick(gradientChip, gradientChip.width / 2, gradientChip.height / 2);
                    root.verify(Config.turntableFinish === "charcoal" && Config.turntableSpeed === "45", "choices work with keyboard");
                    root.verify(!Config.turntableSpin && !Config.turntableTonearm, "toggles work with keyboard");
                    root.verify(!root.find(page.item, "turntableSpeedControl").enabled, "speed control disabled when rotation off");
                    root.verify(!root.find(page.item, "turntableTrackingControl").enabled, "tracking control disabled when arm hidden");
                    break;
                case 2:
                    root.verify(Config.turntableDesign === "minimal" && !root.find(page.item, "turntableBase").visible, "Minimal selection hides preview deck");
                    root.verify(!root.find(page.item, "turntableFinishControl").enabled, "base finish disabled for Minimal");
                    root.verify(Config.turntablePlatter === "sunset" && root.find(page.item, "turntablePlatter_sunset").active, "gradient preset works with pointer");
                    root.verify(root.find(page.item, "turntablePreview")._platterPreset.value === "sunset", "preview follows selected platter");
                    root.press("Sleeve");
                    break;
                case 3:
                    root.verify(Config.turntableDesign === "sleeve" && root.find(page.item, "turntableSleeveArtwork").visible, "Sleeve works with keyboard and live preview");
                    root.verify(root.find(page.item, "turntableFinishControl").enabled, "Sleeve label finish remains configurable");
                    root.press("Reset");
                    break;
                case 4:
                    root.verify(Config.turntableDesign === "classic" && root.find(page.item, "turntableBase").visible, "reset restores Classic deck");
                    root.verify(root.find(page.item, "turntableFinishControl").enabled, "base finish re-enabled for Classic");
                    root.verify(Config.turntablePlatter === "black" && root.find(page.item, "turntablePlatter_black").active, "reset restores black platter");
                    root.verify(Config.turntableFinish === "cream" && Config.turntableSpeed === "33" && Config.turntableSpin && Config.turntableTonearm, "reset restores defaults");
                    Config.setOption("reducedMotion", true);
                    if (Quickshell.env("HELIOS_TURNTABLE_SETTINGS_CAPTURE")) root.press("Sunset");
                    break;
                case 5:
                    root.verify(root.find(page.item, "Motion is paused by Reduce motion."), "reduced motion explained");
                    root.press(root.naturePresets[0]);
                    break;
                default:
                    const natureName = root.naturePresets[root.phase - 6];
                    const natureChip = root.find(page.item, "turntablePlatter_" + natureName.toLowerCase());
                    const natureRecord = root.find(page.item, "turntableRecord");
                    root.verify(Config.turntablePlatter === natureName.toLowerCase() && natureChip.active, "nature gradient selected with keyboard: " + natureName);
                    root.verify(natureRecord.gradient && natureRecord.gradient.stops[0].color.toString() !== natureRecord.gradient.stops[1].color.toString(), "nature gradient visible in preview: " + natureName);
                    root.verify(natureChip.x + natureChip.width <= natureChip.parent.width && natureChip.y + natureChip.height <= natureChip.parent.height, "nature chip fits wrapped layout: " + natureName);
                    if (root.phase - 5 < root.naturePresets.length) {
                        root.press(root.naturePresets[root.phase - 5]);
                        break;
                    }
                    if (Quickshell.env("HELIOS_TURNTABLE_SETTINGS_CAPTURE")) {
                        surface.grabToImage(result => {
                            result.saveToFile(Quickshell.env("HELIOS_TURNTABLE_SETTINGS_CAPTURE"));
                            console.warn("TURNTABLE_SETTINGS_TEST_PASS"); root.finish.start();
                        });
                    } else { console.warn("TURNTABLE_SETTINGS_TEST_PASS"); root.finish.start(); }
                    return;
                }
                root.phase++; advance.restart();
            } catch (error) { console.error("TURNTABLE_SETTINGS_TEST_FAIL", error.toString()); root.finish.start(); }
        }
    }
}
