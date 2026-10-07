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
        for (const child of item.data || item.children || []) {
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
                    Weather.daily = [{date: "2026-10-03", tempC: 25, feelsLikeC: 27, minTempC: 22, maxTempC: 28, condition: "Rain", humidity: 60, windKmph: 36, chanceOfRain: 40}];
                    Weather.hourly = [
                        {label: "Now", tempC: 25, icon: "rainy"},
                        {label: "14:00", tempC: 26, icon: "cloud"},
                        {label: "15:00", tempC: 28, icon: "wb_sunny"},
                        {label: "16:00", tempC: 27, icon: "wb_sunny"},
                        {label: "17:00", tempC: 26, icon: "cloud"},
                        {label: "18:00", tempC: 24, icon: "cloud"}
                    ];
                    root.press("weatherFahrenheit");
                    root.press("mph");
                    root.press("60 min");
                    break;
                case 1:
                    root.verify(root.find(destination, "77°"), "destination follows Fahrenheit setting");
                    root.verify(root.find(destination, "22 mph"), "destination follows wind setting");
                    root.verify(Weather.refreshMinutes === 60, "interval keyboard control works");
                    root.verify(root.find(destination, "Now"), "hourly strip starts with the current hour");
                    root.verify(root.find(destination, "weatherConditionIcon").icon === "rainy", "condition icon follows forecast");
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
                    // Keep late network responses from replacing the navigation fixture.
                    Weather._forecastGeneration++;
                    if (Weather._forecastRequest) Weather._forecastRequest.abort();
                    Weather.daily = [
                        {date: "2026-10-03", tempC: 25, feelsLikeC: 27, minTempC: 22, maxTempC: 28, condition: "Rain", humidity: 60, windKmph: 36, chanceOfRain: 40},
                        {date: "2026-10-04", tempC: 28, feelsLikeC: 29, minTempC: 23, maxTempC: 30, condition: "Clear sky", humidity: 55, windKmph: 18, chanceOfRain: 0}
                    ];
                    root.find(destination, "weatherNextDay").forceActiveFocus();
                    input.keyClick(Qt.Key_Space);
                    break;
                case 7:
                    root.verify(destination.dayOffset === 1 && root.find(destination, "82°"), "keyboard navigation updates hero temperature");
                    root.verify(root.find(destination, "weatherConditionIcon").icon === "wb_sunny", "icon follows selected forecast day");
                    root.find(destination, "weatherDatePickerButton").forceActiveFocus();
                    input.keyClick(Qt.Key_Space);
                    break;
                case 8:
                    root.verify(destination.pickerOpen && root.find(destination, "weatherDatePicker").visible, "date picker opens from day button");
                    input.keyClick(Qt.Key_Escape);
                    break;
                case 9:
                    root.verify(!destination.pickerOpen, "Escape closes the date picker");
                    break;
                case 10:
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
