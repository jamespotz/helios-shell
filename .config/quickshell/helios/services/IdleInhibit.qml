pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Idle / auto-lock service — manages hypridle configuration for
// automatic screen dimming, DPMS off, and session lock after timeout.
// Writes a runtime config file and spawns/kills hypridle as needed.
QtObject {
    id: root

    // Aliased straight to the JsonAdapter's own properties (see
    // services/Bridge.qml's liquidGlassEnabled fix for the full story)
    // rather than mirrored into plain properties restored in
    // Component.onCompleted — FileView loads asynchronously, so a
    // Component.onCompleted snapshot read the adapter's compiled-in
    // defaults before the real values had loaded from disk, silently
    // resetting every persisted idle-inhibit setting on each shell restart.
    property alias enabled: adapter.enabled
    property alias lockTimeout: adapter.lockTimeout      // seconds before lock (0 = never)
    property alias dpmsTimeout: adapter.dpmsTimeout      // seconds before DPMS off (0 = never)
    property alias dimTimeout: adapter.dimTimeout        // seconds before dimming (0 = never)
    property bool inhibited: false     // temporary caffeine mode — not persisted

    readonly property string configPath: Quickshell.env("HOME") + "/.config/hypr/hypridle-helios.conf"
    readonly property string helios: "quickshell -c helios ipc call"

    function setEnabled(v) {
        root.enabled = v;
        root._sync();
    }

    function setLockTimeout(secs) {
        root.lockTimeout = Math.max(0, secs);
        root._sync();
    }

    function setDpmsTimeout(secs) {
        root.dpmsTimeout = Math.max(0, secs);
        root._sync();
    }

    function setDimTimeout(secs) {
        root.dimTimeout = Math.max(0, secs);
        root._sync();
    }

    function toggleInhibit() {
        root.inhibited = !root.inhibited;
        root._sync();
    }

    function _sync() {
        // Kill existing hypridle
        killProc.running = false;
        killProc.running = true;
    }

    function _writeConfigAndStart() {
        if (!root.enabled || root.inhibited) return;

        // Build hypridle config lines
        let lines = [];
        lines.push("general {");
        lines.push("    lock_cmd = " + root.helios + " lock lock");
        lines.push("    before_sleep_cmd = loginctl lock-session");
        lines.push("    after_sleep_cmd = hyprctl dispatch dpms on");
        lines.push("}");
        lines.push("");

        if (root.dimTimeout > 0) {
            lines.push("listener {");
            lines.push("    timeout = " + root.dimTimeout);
            lines.push("    on-timeout = brightnessctl -s set 30%");
            lines.push("    on-resume = brightnessctl -r");
            lines.push("}");
            lines.push("");
        }

        if (root.lockTimeout > 0) {
            lines.push("listener {");
            lines.push("    timeout = " + root.lockTimeout);
            lines.push("    on-timeout = " + root.helios + " lock lock");
            lines.push("}");
            lines.push("");
        }

        if (root.dpmsTimeout > 0) {
            lines.push("listener {");
            lines.push("    timeout = " + root.dpmsTimeout);
            lines.push("    on-timeout = hyprctl dispatch dpms off");
            lines.push("    on-resume = hyprctl dispatch dpms on");
            lines.push("}");
            lines.push("");
        }

        const config = lines.join("\\n");
        // Use printf to write config file then exec hypridle.
        // If hypridle isn't installed, this just silently fails.
        writeProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%b' '" + config + "' > '" + root.configPath + "' && " +
            "command -v hypridle >/dev/null 2>&1 && exec hypridle -c '" + root.configPath + "'"
        ];
        writeProc.running = false;
        writeProc.running = true;
    }

    property Process killProc: Process {
        command: ["pkill", "-x", "hypridle"]
        onExited: {
            startDelay.restart();
        }
    }

    property Timer startDelay: Timer {
        interval: 150
        onTriggered: root._writeConfigAndStart()
    }

    property Process writeProc: Process {}

    // Persistence
    property FileView settingsFile: FileView {
        path: Quickshell.statePath("idle-settings.json")
        watchChanges: false

        JsonAdapter {
            id: adapter
            property bool enabled: true
            property int lockTimeout: 300
            property int dpmsTimeout: 600
            property int dimTimeout: 240
        }

        // Fires once the async load actually completes — the correct place
        // to act on the *real* restored `enabled`, unlike Component.onCompleted
        // (see the comment on the aliases above).
        onLoaded: root._sync()
    }

    onEnabledChanged: root.settingsFile.writeAdapter()
    onLockTimeoutChanged: root.settingsFile.writeAdapter()
    onDpmsTimeoutChanged: root.settingsFile.writeAdapter()
    onDimTimeoutChanged: root.settingsFile.writeAdapter()
}
