pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Idle / auto-lock service: dims, locks, and turns the display off after
// the user's timeouts, using Wayland idle notifications.
QtObject {
    id: root

    // Aliased straight to the JsonAdapter's own properties (see
    // services/ShellState.qml's liquidGlassEnabled fix for the full story)
    // rather than mirrored into plain properties restored in
    // Component.onCompleted — FileView loads asynchronously, so a
    // Component.onCompleted snapshot read the adapter's compiled-in
    // defaults before the real values had loaded from disk, silently
    // resetting every persisted idle-inhibit setting on each shell restart.
    property alias enabled: adapter.enabled
    property alias lockTimeout: adapter.lockTimeout      // seconds before lock (0 = never)
    property alias dpmsTimeout: adapter.dpmsTimeout      // seconds before DPMS off (0 = never)
    property alias dimTimeout: adapter.dimTimeout        // seconds before dimming (0 = never)
    property alias caffeine: adapter.inhibited           // the user's caffeine toggle
    readonly property bool inhibited: root.caffeine || GameMode.enabled

    function setEnabled(v) { root.enabled = v; }
    function setLockTimeout(secs) { root.lockTimeout = Math.max(0, secs); }
    function setDpmsTimeout(secs) { root.dpmsTimeout = Math.max(0, secs); }
    function setDimTimeout(secs) { root.dimTimeout = Math.max(0, secs); }
    function toggleInhibit() { root.caffeine = !root.caffeine; }

    // Off until the saved settings load, so defaults never fire.
    readonly property bool _active: root.settingsFile.loaded && root.enabled && !root.inhibited

    // IdleMonitor respects app idle inhibitors (video players, browsers) by default.
    property IdleMonitor dimMonitor: IdleMonitor {
        enabled: root._active && root.dimTimeout > 0
        timeout: root.dimTimeout
        onIsIdleChanged: Quickshell.execDetached(isIdle ? ["brightnessctl", "-s", "set", "30%"] : ["brightnessctl", "-r"])
    }
    property IdleMonitor lockMonitor: IdleMonitor {
        enabled: root._active && root.lockTimeout > 0
        timeout: root.lockTimeout
        onIsIdleChanged: if (isIdle) ShellState.lock()
    }
    property IdleMonitor dpmsMonitor: IdleMonitor {
        enabled: root._active && root.dpmsTimeout > 0
        timeout: root.dpmsTimeout
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
    }

    // Lock before sleep: hold a logind delay inhibitor while unlocked, lock on
    // PrepareForSleep, and drop the inhibitor once the lock is secure so
    // suspend proceeds without showing the desktop on wake.
    // pdeathsig ends both if the shell is killed; tail exits with systemd-inhibit.
    // An orphaned inhibitor would delay every suspend.
    property Process sleepInhibitor: Process {
        running: root.enabled && !ShellState.lockSecure
        command: ["setpriv", "--pdeathsig", "TERM", "--", "systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Helios",
            "--why=Lock the screen before sleep", "sh", "-c", "exec tail --pid=$PPID -f /dev/null"]
    }
    property Process sleepWatcher: Process {
        running: root.enabled
        command: ["setpriv", "--pdeathsig", "TERM", "--", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => { if (line.includes("PrepareForSleep (true")) ShellState.lock(); }
        }
    }

    // Persistence
    property FileView settingsFile: FileView {
        path: Quickshell.statePath("idle-settings.json")
        watchChanges: false
        onAdapterUpdated: root.saveTimer.restart()

        JsonAdapter {
            id: adapter
            property bool enabled: true
            property int lockTimeout: 300
            property int dpmsTimeout: 600
            property int dimTimeout: 240
            property bool inhibited: false
        }

    }

    // Adapter updates exclude disk loading, so restoring preferences never
    // writes a partially restored snapshot back over the saved settings.
    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: root.settingsFile.writeAdapter()
    }
}
