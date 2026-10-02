import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "services"
import "modules/settings" as SettingsUI
import "modules/island" as IslandUI

ShellRoot {
    id: root
    property int phase: 0
    TestCase { id: input; name: "WeatherSettings"; when: false }
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 150; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, value, action) {
        if ((item.objectName === value || item.text === value || item.label === value) && (!action || item.clicked || item.toggled)) return item;
        for (const child of item.children || []) {
            const result = root.find(child, value, action);
            if (result) return result;
        }
        return null;
    }
    function press(value) {
        const button = root.find(settings, value, true);
        root.verify(button && button.enabled, "button available: " + value);
        button.forceActiveFocus();
        input.keyClick(Qt.Key_Space);
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1100
        implicitHeight: 1000
        color: Colors.background
        Item {
            id: surface
            anchors.fill: parent
            SettingsUI.WeatherSettings { id: settings; x: 20; y: 20; width: 420 }
            IslandUI.WeatherDestination { id: destination; x: 460; y: 20 }
            IslandUI.WeatherEffectMini { id: effect; x: 460; y: 600; width: 400; height: 200; anchors.fill: undefined }
        }
    }
    Timer {
        id: advance
        interval: 160
        running: true
        onTriggered: {
            try {
                switch (root.phase) {
                case 0:
                    Weather.refreshTimer.stop();
                    Weather.requestTimer.stop();
                    Weather.retryTimer.stop();
                    Weather.loading = false;
                    Weather.available = true;
                    Weather.tempC = 25;
                    Weather.condition = "Rain";
                    Weather.daily = [{date: "2026-10-03", tempC: 25, feelsLikeC: 27, condition: "Rain", humidity: 60, windKmph: 36, chanceOfRain: 40}];
                    root.press("weatherFahrenheit");
                    root.press("mph");
                    root.press("60 min");
                    break;
                case 1:
                    root.verify(root.find(destination, "77°"), "destination follows Fahrenheit setting");
                    root.verify(root.find(destination, "22 mph"), "destination follows wind setting");
                    root.verify(Weather.refreshMinutes === 60, "interval keyboard control works");
                    root.press("Weather animations");
                    break;
                case 2:
                    root.verify(!effect.visible, "disabled weather effects hidden");
                    root.press("Weather animations");
                    Config.setOption("reducedMotion", true);
                    break;
                case 3:
                    root.verify(!effect.motionEnabled, "reduced motion stops effects");
                    root.verify(root.find(settings, "Animations are paused by Reduce motion."), "reduced motion explained");
                    Config.setOption("reducedMotion", false);
                    root.find(settings, "weatherLocationInput").text = "Paris";
                    Weather.searchResults = [
                        {name: "Paris", admin1: "Île-de-France", country: "France", latitude: 48.85, longitude: 2.35},
                        {name: "Paris", admin1: "Texas", country: "United States", latitude: 33.66, longitude: -95.55}
                    ];
                    break;
                case 4: {
                    const field = root.find(settings, "weatherLocationInput");
                    field.focusInput();
                    input.keyClick(Qt.Key_Down);
                    input.keyClick(Qt.Key_Return);
                    break;
                }
                case 5:
                    root.verify(Weather.locationOverride === "33.66,-95.55", "keyboard chooses second matching city");
                    root.verify(Weather.locationName === "Paris, Texas, United States", "selected city name retained");
                    root.verify(Weather.searchResults.length === 0, "selection dismisses results");
                    root.verify(!root.find(settings, "weatherRefreshButton").enabled, "refresh disabled during request");
                    Weather.requestTimer.stop();
                    Weather.loading = false;
                    Weather.available = true;
                    Weather.location = "Paris, Texas, United States";
                    Weather.lastUpdated = Date.now();
                    Weather.error = "Weather request failed. Check your connection and try again.";
                    break;
                case 6:
                    root.verify(root.find(settings, Weather.error), "request error visible");
                    if (Quickshell.env("HELIOS_WEATHER_CAPTURE")) {
                        surface.grabToImage(result => {
                            result.saveToFile(Quickshell.env("HELIOS_WEATHER_CAPTURE"));
                            console.warn("WEATHER_UI_TEST_PASS");
                            root.terminateDelay.start();
                        });
                    } else {
                        console.warn("WEATHER_UI_TEST_PASS");
                        root.terminateDelay.start();
                    }
                    return;
                }
                root.phase++;
                advance.restart();
            } catch (error) {
                console.error("WEATHER_UI_TEST_FAIL", error.toString());
                root.terminateDelay.start();
            }
        }
    }
}
