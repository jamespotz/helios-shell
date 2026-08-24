pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light / color temperature service — manages wlsunset process.
// Supports manual toggle with a configurable temperature (1000K–6500K)
// and an auto-schedule mode (sunset-to-sunrise via latitude/longitude).
QtObject {
    id: root

    property bool enabled: false
    property int temperature: 4000  // Kelvin (warm end when active)
    property int dayTemp: 6500      // Kelvin (neutral daylight)
    property bool scheduled: false
    property real latitude: 0.0
    property real longitude: 0.0

    readonly property int tempMin: 1000
    readonly property int tempMax: 6500

    function toggle() {
        root.enabled = !root.enabled;
        root._sync();
    }

    function setEnabled(v) {
        root.enabled = v;
        root._sync();
    }

    function setTemperature(temp) {
        root.temperature = Math.max(root.tempMin, Math.min(root.tempMax, temp));
        if (root.enabled) root._sync();
    }

    function setScheduled(v, lat, lon) {
        root.scheduled = v;
        if (lat !== undefined) root.latitude = lat;
        if (lon !== undefined) root.longitude = lon;
        if (root.enabled) root._sync();
    }

    function _sync() {
        // Kill existing wlsunset first
        if (killProc.running) killProc.running = false;
        killProc.running = true;
    }

    // Kill any existing wlsunset before spawning a new one
    property Process killProc: Process {
        command: ["pkill", "-x", "wlsunset"]
        onExited: {
            if (root.enabled) startDelay.restart();
        }
    }

    property Timer startDelay: Timer {
        interval: 100
        onTriggered: {
            // wlsunset -T = high temp (day), -t = low temp (night/target)
            // In manual mode, force permanent night by setting sunset in the
            // past and sunrise far in the future. wlsunset uses 24h format.
            const args = ["wlsunset", "-T", String(root.dayTemp), "-t", String(root.temperature)];
            if (root.scheduled && root.latitude !== 0 && root.longitude !== 0) {
                args.push("-l", String(root.latitude), "-L", String(root.longitude));
            } else {
                // Manual "always night" mode: sunset at 00:01, sunrise at 23:59
                // This makes wlsunset think it's permanently past sunset.
                args.push("-s", "00:01", "-S", "23:59");
            }
            proc.command = args;
            proc.running = false;
            proc.running = true;
        }
    }

    property Process proc: Process {}

    // Persisted settings
    property FileView settingsFile: FileView {
        path: Quickshell.statePath("nightlight.json")
        watchChanges: false

        JsonAdapter {
            id: adapter
            property bool enabled: false
            property int temperature: 4000
            property bool scheduled: false
            property real latitude: 0.0
            property real longitude: 0.0
        }
    }

    property bool _loaded: false

    Component.onCompleted: {
        // Restore saved state
        root.enabled = adapter.enabled;
        root.temperature = adapter.temperature;
        root.scheduled = adapter.scheduled;
        root.latitude = adapter.latitude;
        root.longitude = adapter.longitude;
        root._loaded = true;
        if (root.enabled) root._sync();
    }

    onEnabledChanged: { if (root._loaded) { adapter.enabled = root.enabled; root.settingsFile.writeAdapter(); } }
    onTemperatureChanged: { if (root._loaded) { adapter.temperature = root.temperature; root.settingsFile.writeAdapter(); } }
    onScheduledChanged: { if (root._loaded) { adapter.scheduled = root.scheduled; root.settingsFile.writeAdapter(); } }
    onLatitudeChanged: { if (root._loaded) { adapter.latitude = root.latitude; root.settingsFile.writeAdapter(); } }
    onLongitudeChanged: { if (root._loaded) { adapter.longitude = root.longitude; root.settingsFile.writeAdapter(); } }
}
