import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/island" as IslandUI
import "modules/settings" as SettingsUI

ShellRoot {
    id: root
    TestCase { id: input; name: "SatelliteFocus"; when: false }
    property int contentInstances: 0
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function findOption(item, option) {
        if (item.option === option) return item;
        for (const child of item.children || []) {
            const found = root.findOption(child, option);
            if (found) return found;
        }
        return null;
    }
    function findText(item, text) {
        if (item.text === text && item.clicked) return item;
        const children = item.children || [];
        for (let i = 0; i < children.length; i++) {
            const found = root.findText(children[i], text);
            if (found) return found;
        }
        return null;
    }
    readonly property Timer hostCheck: Timer {
        interval: 80
        onTriggered: {
            try {
                root.verify(recordingHost.height > 100, "tall main Island leaves satellite content visible beside it");
                const stop = root.findText(recordingHost, "Stop recording");
                root.verify(stop && !stop.enabled, "stop unavailable when recording has finished");
                const recorder = root.findText(recordingHost, "Open Recorder");
                root.verify(recorder, "recording controls instantiate in shared host");
                anchor.forceActiveFocus();
                input.mouseClick(recordingHost, 10, 50);
                root.verify(recordingHost.activeFocus, "pointer interaction restores satellite keyboard focus");
                recorder.clicked();
                root.verify(IslandNavigation.destinationId === "recorder" && IslandNavigation.panelOpenFor("test-screen"), "Recorder action opens main destination on correct screen");
                root.verify(!recordingHost.expanded && !root.findText(recordingHost, "Open Recorder"), "Recorder action closes and unloads satellite controls");
                IslandNavigation.close();
                console.warn("ISLAND_SATELLITE_UI_TEST_PASS");
            } catch (error) { console.error("ISLAND_SATELLITE_UI_TEST_FAIL:", error.toString()); }
            root.terminateDelay.start();
        }
    }
    FloatingWindow {
        width: 1000
        height: 800
        visible: true
        Item {
            id: surface
            width: 1000
            height: 800
            FocusScope { id: anchor; x: 400; width: 200; height: 32 }
            IslandUI.IslandShape { id: mainShape; width: 200; height: 100; visible: false }
            SettingsUI.IslandSettings { id: settings; width: 700; visible: false }
            IslandUI.IslandSatelliteHost {
                id: recordingHost
                anchorItem: anchor
                definition: IslandNavigation.satellites[0]
                targetScreen: "test-screen"
            }
            IslandUI.IslandSatellite {
                id: satellite
                anchorItem: anchor
                expandedContent: Component {
                    Item {
                        implicitWidth: 240
                        implicitHeight: 100
                        Component.onCompleted: root.contentInstances++
                        Component.onDestruction: root.contentInstances--
                    }
                }
            }
        }
    }
    Component.onCompleted: {
        try {
            Config.setOption("reducedMotion", true);
            const idleRadiusSlider = root.findOption(settings, "islandIdleCornerRadius");
            root.verify(idleRadiusSlider && idleRadiusSlider.from === 0 && idleRadiusSlider.to === 48, "settings exposes Idle corner radius range");
            idleRadiusSlider.moved(8);
            root.verify(mainShape.cornerRadius === 8, "Idle uses its own radius");
            const radiusSlider = root.findOption(settings, "islandExpandedCornerRadius");
            root.verify(radiusSlider && radiusSlider.from === 0 && radiusSlider.to === 48, "settings exposes corner radius range");
            radiusSlider.moved(30);
            root.verify(mainShape.cornerRadius === 8, "Expanded radius leaves Idle unchanged");
            mainShape.expanded = true;
            root.verify(mainShape.cornerRadius === 30, "main Island radius follows settings live");
            root.verify(radiusSlider.value === 30, "slider displays applied radius");
            const satelliteShape = satellite.children.find(item => item.cornerRadius !== undefined);
            satellite.expanded = true;
            root.verify(satelliteShape && satelliteShape.cornerRadius === 18, "main radius leaves satellite corners unchanged");
            satellite.expanded = false;
            mainShape.height = 32;
            root.verify(mainShape.cornerRadius === 16, "compact shape radius caps at half height");
            mainShape.height = 100;
            Config.setOption("islandExpandedCornerRadius", 0);
            root.verify(mainShape.cornerRadius === 0, "zero radius allows square corners");
            Config.setOption("islandExpandedCornerRadius", 100);
            root.verify(mainShape.cornerRadius === 48, "radius setting clamps to maximum");
            const radiusPreset = Config._islandPreset();
            Config.resetOptions(["islandExpandedCornerRadius"]);
            root.verify(mainShape.cornerRadius === 18, "reset restores default corners");
            mainShape.expanded = false;
            root.verify(mainShape.cornerRadius === 8, "Expanded reset preserves Idle radius");
            mainShape.expanded = true;
            Config._applyIslandPreset(radiusPreset);
            root.verify(mainShape.cornerRadius === 48, "preset restores radius");
            Config.resetOptions(["islandIdleCornerRadius", "islandExpandedCornerRadius"]);
            root.verify(root.contentInstances === 0, "collapsed satellite does not instantiate destination");
            satellite.expanded = true;
            root.verify(root.contentInstances === 1, "opening loads one destination");
            root.verify(satellite.gap === Config.satelliteRestGap, "expanded-only satellite reserves gap");
            root.verify(satellite.width >= 240, "opening measures destination");
            satellite.expanded = false;
            root.verify(root.contentInstances === 0, "closing unloads destination");
            satellite.active = true;
            root.verify(satellite.gap === Config.satelliteRestGap, "reduced motion skips entrance tween");
            root.verify(satellite.opacity === 1, "reduced motion skips fade");
            satellite.active = false;
            root.verify(satellite.opacity === 0, "reduced motion hides immediately");
            surface.width = 500;
            anchor.x = 150;
            satellite.expanded = true;
            root.verify(satellite.below, "narrow surface places expanded satellite below Island");
            root.verify(satellite.x >= 0 && satellite.x + satellite.width <= surface.width, "expanded satellite stays inside surface");
            root.verify(satellite.y >= anchor.y + anchor.height, "expanded satellite does not overlap main Island");
            satellite.expanded = false;
            surface.width = 1000;
            anchor.x = 400;
            anchor.height = 800;
            IslandNavigation.show("test-screen", "calendar");
            IslandNavigation.showSatellite("test-screen", "recording");
            root.verify(recordingHost.expanded, "shared host follows satellite navigation");
            root.hostCheck.start();
            return;
        } catch (error) { console.error("ISLAND_SATELLITE_UI_TEST_FAIL:", error.toString()); }
        root.terminateDelay.start();
    }
}
