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
            root.verify(Weather.conditionFor(95) === "Thunderstorm", "WMO code maps to text");
            root.verify(Weather.conditionFor(1234) === "Cloudy", "unknown code falls back");
            root.verify(Weather.iconFor("Thunderstorm with hail") === "thunderstorm", "thunder wins over other keywords");
            root.verify(Weather.iconFor("Slight snow fall") === "ac_unit", "snow icon");
            root.verify(Weather.iconFor("Light drizzle") === "rainy", "drizzle is rain");
            root.verify(Weather.iconFor("Clear sky") === "wb_sunny", "clear is sunny");
            root.verify(Weather.iconFor("Clear sky", true) === "clear_night", "clear night shows the moon");
            root.verify(Weather.iconFor("") === "cloud", "empty falls back");
            root.verify(typeof Weather.formatTemperature === "function", "temperature formatting available");
            root.verify(Weather.formatTemperature(0) === "0°", "Celsius default");
            Weather.setOption("temperatureUnit", "fahrenheit");
            root.verify(Weather.formatTemperature(0, true) === "32°F", "freezing in Fahrenheit");
            root.verify(Weather.formatTemperature(-40) === "-40°", "negative temperature conversion");
            Weather.setOption("windUnit", "mph");
            root.verify(Weather.formatWind(100) === "62 mph", "wind conversion to mph: " + Weather.windUnit + " / " + Weather.formatWind(100));
            Weather.setOption("windUnit", "ms");
            root.verify(Weather.formatWind(36) === "10 m/s", "wind conversion to metres per second");
            Weather.setOption("refreshMinutes", 60);
            root.verify(Weather.refreshTimer.interval === 3600000, "refresh timer follows preference");
            Weather.setOption("refreshMinutes", 0);
            root.verify(Weather.refreshMinutes === 60, "invalid interval rejected");
            Weather.setOption("temperatureUnit", "kelvin");
            root.verify(Weather.temperatureUnit === "fahrenheit", "invalid temperature unit rejected");
            root.verify(Weather.parseCoordinates(" 14.6, 121.0 ").longitude === 121, "coordinates parsed");
            root.verify(Weather.parseCoordinates("91,181") === null, "invalid coordinates rejected");
            root.verify(Weather.locationLabel({name: "Paris", admin1: "Texas", country: "United States"}) === "Paris, Texas, United States", "ambiguous cities distinguished");
            Weather.setOption("animationsEnabled", false);
            root.verify(!Weather.animationsEnabled, "effects can be disabled");
            console.warn("WEATHER_TEST_PASS");
        } catch (error) {
            console.error("WEATHER_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
