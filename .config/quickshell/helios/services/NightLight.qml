pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night light / color temperature service — manages wlsunset process.
// Supports manual toggle with a configurable temperature (1000K–6500K)
// and an auto-schedule mode (sunset-to-sunrise using the same lat/long
// as the Weather service's resolved location — see Weather.qml).
QtObject {
    id: root

    // Aliased straight to the JsonAdapter's own properties (see
    // services/Bridge.qml's liquidGlassEnabled fix for the full story)
    // rather than mirrored into plain properties restored in
    // Component.onCompleted — FileView loads asynchronously, so a
    // Component.onCompleted snapshot read the adapter's compiled-in
    // defaults before the real values had loaded from disk, silently
    // resetting every persisted night-light setting on each shell restart.
    property alias enabled: adapter.enabled
    property alias temperature: adapter.temperature
    property alias scheduled: adapter.scheduled

    property int dayTemp: 6500      // Kelvin (neutral daylight) — not persisted

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

    function setScheduled(v) {
        root.scheduled = v;
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
            if (root.scheduled && Weather.latitude !== 0 && Weather.longitude !== 0) {
                args.push("-l", String(Weather.latitude), "-L", String(Weather.longitude));
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
        }

        // Fires once the async load actually completes — the correct place
        // to act on the *real* restored `enabled`, unlike Component.onCompleted
        // (see the comment on the aliases above).
        onLoaded: if (root.enabled) root._sync()
    }

    onEnabledChanged: root.settingsFile.writeAdapter()
    onTemperatureChanged: root.settingsFile.writeAdapter()
    onScheduledChanged: root.settingsFile.writeAdapter()

    // Re-sync when the shared weather location resolves/changes so a
    // scheduled night light picks up sunset/sunrise for the right place
    // without requiring the shell to restart.
    property Connections weatherWatcher: Connections {
        target: Weather
        function onLatitudeChanged() { if (root.enabled && root.scheduled) root._sync(); }
        function onLongitudeChanged() { if (root.enabled && root.scheduled) root._sync(); }
    }
}
