import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/settings" as SettingsUI

ShellRoot {
    id: root
    property int phase: 0
    property real previewY: 0
    property real controlHeight: 0
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer finish: Timer { interval: 100; onTriggered: root.terminator.running = true }
    TestCase { id: input; name: "SettingsPreviews"; when: false }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (!item) return null;
        if (item.objectName === name) return item;
        for (const child of item.children || []) { const found = root.find(child, name); if (found) return found; }
        return null;
    }
    function scrollControls() {
        const frame = root.find(page.item, "settingsPreviewFrame");
        const flick = root.find(page.item, "settingsControlsFlick");
        root.verify(frame && frame.height > 0 && frame.height <= 180, "compact preview available");
        root.verify(flick && flick.height > 200 && flick.contentHeight > flick.height, "scrollable controls have room");
        root.previewY = frame.mapToItem(surface, 0, 0).y;
        flick.contentY = flick.contentHeight - flick.height;
    }
    function verifySticky() {
        const frame = root.find(page.item, "settingsPreviewFrame");
        const flick = root.find(page.item, "settingsControlsFlick");
        root.verify(flick.contentY > 100, "controls actually scrolled");
        root.verify(frame.mapToItem(surface, 0, 0).y === root.previewY, "preview stays fixed while controls scroll");
    }
    FloatingWindow {
        visible: true
        implicitWidth: 600
        implicitHeight: 500
        color: Colors.background
        Item {
            id: surface
            anchors.fill: parent
            Loader { id: page; x: 20; y: 20; width: 560; height: 460; sourceComponent: turntablePage }
        }
    }
    Component { id: turntablePage; SettingsUI.TurntableSettings {} }
    Component { id: islandPage; SettingsUI.IslandSettings {} }
    Component { id: dockPage; SettingsUI.DockSettings {} }
    Timer {
        id: advance
        interval: 250
        running: true
        onTriggered: {
            try {
                switch (root.phase) {
                case 0:
                    root.verify(page.status === Loader.Ready, "Turntable page loads");
                    root.scrollControls();
                    Config.setOption("turntablePlatter", "forest");
                    break;
                case 1:
                    root.verifySticky();
                    root.verify(root.find(page.item, "turntableRecord").gradient.stops[0].color.toString() === "#9bbf85", "Turntable updates while scrolled");
                    page.sourceComponent = islandPage;
                    break;
                case 2:
                    root.verify(page.status === Loader.Ready, "Island page loads");
                    root.scrollControls();
                    Config.setOption("idleBumpHeight", 48);
                    break;
                case 3:
                    root.verifySticky();
                    root.verify(root.find(page.item, "islandPreviewIdle").implicitHeight === 48, "Island updates while scrolled");
                    page.sourceComponent = dockPage;
                    break;
                case 4:
                    root.verify(page.status === Loader.Ready, "Dock page loads");
                    root.scrollControls();
                    Dock.setOption("position", "left");
                    Dock.setOption("iconSize", 64);
                    Dock.setOption("iconSpacing", 20);
                    Dock.setOption("edgePadding", 20);
                    Dock.setOption("alignment", "end");
                    break;
                case 5:
                    root.verifySticky();
                    const leftBody = root.find(page.item, "dockPreviewBody");
                    root.verify(leftBody.height > leftBody.width && leftBody.x === Dock.edgeGap, "Dock position updates while scrolled");
                    root.verify(leftBody.width === 104 && leftBody.scale > 0 && leftBody.scale <= 1, "Dock size/padding update and fit stage");
                    Dock.setOption("position", "right");
                    break;
                case 6:
                    const rightBody = root.find(page.item, "dockPreviewBody");
                    root.verify(rightBody.x > rightBody.parent.width / 2, "right Dock stays on right of stage");
                    Dock.setOption("position", "bottom");
                    Dock.setOption("iconSize", 44);
                    Dock.setOption("iconSpacing", 6);
                    Dock.setOption("edgePadding", 8);
                    Dock.setOption("alignment", "center");
                    Dock.setOption("magnify", true);
                    Dock.setOption("magnifyScale", 1.8);
                    Config.setOption("reducedMotion", false);
                    break;
                case 7:
                    const visual = root.find(page.item, "dockPreviewIcon_0");
                    input.mouseMove(visual, visual.width / 2, visual.height / 2);
                    break;
                case 8:
                    root.verify(root.find(page.item, "dockPreviewIcon_0").scale > 1.2, "Dock hover demonstrates magnification");
                    Config.setOption("reducedMotion", true);
                    break;
                case 9:
                    root.verify(root.find(page.item, "dockPreviewIcon_0").scale === 1, "Dock preview respects reduced motion");
                    if (Quickshell.env("HELIOS_SETTINGS_PREVIEW_CAPTURE")) {
                        surface.grabToImage(result => {
                            result.saveToFile(Quickshell.env("HELIOS_SETTINGS_PREVIEW_CAPTURE"));
                            console.warn("SETTINGS_PREVIEWS_TEST_PASS"); root.finish.start();
                        });
                    } else { console.warn("SETTINGS_PREVIEWS_TEST_PASS"); root.finish.start(); }
                    return;
                }
                root.phase++; advance.restart();
            } catch (error) { console.error("SETTINGS_PREVIEWS_TEST_FAIL", error.toString()); root.finish.start(); }
        }
    }
}
