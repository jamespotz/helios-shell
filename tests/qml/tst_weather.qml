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
            root.verify(Weather.iconFor("") === "cloud", "empty falls back");
            console.warn("WEATHER_TEST_PASS");
        } catch (error) {
            console.error("WEATHER_TEST_FAIL:", error.toString());
        }
        root.terminateDelay.start();
    }
}
