import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    Component.onCompleted: Weather.refreshTimer.stop()
    property bool writing: Quickshell.env("HELIOS_WEATHER_PHASE") === "write"
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 300; onTriggered: root.terminator.running = true }
    Timer {
        interval: 250
        running: true
        onTriggered: {
            try {
                if (root.writing) {
                    Weather.selectLocation({name: "Paris", admin1: "Texas", country: "United States", latitude: 33.66, longitude: -95.55});
                    Weather.setOption("temperatureUnit", "fahrenheit");
                    Weather.setOption("windUnit", "ms");
                    Weather.setOption("refreshMinutes", 60);
                    Weather.setOption("animationsEnabled", false);
                } else {
                    const actual = [Weather.locationOverride, Weather.locationName, Weather.temperatureUnit,
                        Weather.windUnit, Weather.refreshMinutes, Weather.animationsEnabled];
                    const expected = ["33.66,-95.55", "Paris, Texas, United States", "fahrenheit", "ms", 60, false];
                    if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error(JSON.stringify(actual));
                    if (Weather.formatTemperature(0, true) !== "32°F") throw new Error("restored temperature preference ignored");
                    if (Weather.refreshTimer.interval !== 3600000) throw new Error("restored refresh interval ignored");
                }
                console.warn("WEATHER_PERSISTENCE_TEST_PASS");
            } catch (error) { console.error("WEATHER_PERSISTENCE_TEST_FAIL", error.toString()); }
            root.terminateDelay.start();
        }
    }
}
