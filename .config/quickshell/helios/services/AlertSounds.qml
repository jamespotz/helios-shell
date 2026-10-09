pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Plays freedesktop sounds for the shell. Alert sounds go with an alert card
// appearing — new notification (not low urgency), meeting reminder, low
// device battery — and need Settings > Island > Alerts > Alert sounds.
// Interface sounds confirm a direct change — volume keys, recording
// start/stop, a drive or Bluetooth device arriving or leaving, the charger,
// a failed authentication, and the shared controls (a button press, a
// toggle flipping, a slider crossing a detent) — and need Interface sounds.
// Both are off by default. Each sound fires on the same signal that drives its motion, so
// the two land together. Referenced once from shell.qml so it exists from
// startup.
QtObject {
    id: root

    readonly property var soundFor: ({
        notify: "message-new-instant", meeting: "bell", battery: "dialog-warning", "focus-timer": "bell",
        volume: "audio-volume-change", "recording-start": "dialog-information", "recording-stop": "complete",
        "device-added": "device-added", "device-removed": "device-removed",
        "power-plug": "power-plug", "power-unplug": "power-unplug", "auth-failed": "dialog-error"
    })
    readonly property var interfaceKinds: ["volume", "recording-start", "recording-stop", "device-added",
        "device-removed", "power-plug", "power-unplug", "auth-failed", "tap", "toggle-on", "toggle-off", "tick"]

    // The freedesktop theme has no click, so control sounds are short
    // synthesized ticks in data/sounds, mixed 6 dB down. Not QtMultimedia's
    // SoundEffect: it starts its own PipeWire device watcher, which spins on
    // a dead socket when a Bluetooth sink disappears and hangs the shell.
    readonly property var fileFor: ({
        tap: "tap.wav", "toggle-on": "toggle-on.wav", "toggle-off": "toggle-off.wav", tick: "tick.wav"
    })

    // Interface sounds land with their motion, so they play from the sound
    // server's sample cache (~5 ms) rather than canberra-gtk-play, which
    // starts GTK on every call (~200 ms). A sample is uploaded on first use
    // and again if the server restarted and dropped it. Alerts aren't
    // frame-sensitive and keep canberra, which follows the sound theme.
    function _sampleFile(kind) {
        return root.fileFor[kind] ? Quickshell.shellPath("data/sounds/" + root.fileFor[kind])
            : "/usr/share/sounds/freedesktop/stereo/" + root.soundFor[kind] + ".oga";
    }
    function _playSample(kind) {
        Quickshell.execDetached(["sh", "-c", 'pactl play-sample "$1" 2>/dev/null || { pactl upload-sample "$2" "$1" && pactl play-sample "$1"; }',
            "sh", "helios-" + kind, root._sampleFile(kind)]);
    }
    // Upload when Interface sounds turns on, so the first press isn't late.
    function _uploadSamples() {
        if (!Config.interfaceSounds) return;
        for (const kind of root.interfaceKinds)
            Quickshell.execDetached(["pactl", "upload-sample", root._sampleFile(kind), "helios-" + kind]);
    }
    property Connections _interfaceToggle: Connections {
        target: Config
        function onInterfaceSoundsChanged() { root._uploadSamples(); }
    }
    Component.onCompleted: root._uploadSamples()

    // A held volume key repeats faster than the pop is long; one per window.
    readonly property int volumeThrottle: 120
    property real _lastVolumeSound: 0

    function play(kind) {
        if (!root.fileFor[kind] && !root.soundFor[kind]) return;
        // Timer completion is an explicit alarm, independent of both toggles.
        const enabled = kind === "focus-timer" || (root.interfaceKinds.includes(kind) ? Config.interfaceSounds : Config.alertSounds);
        if (!enabled) return;
        if (kind === "volume") {
            const now = Date.now();
            if (now - root._lastVolumeSound < root.volumeThrottle) return;
            root._lastVolumeSound = now;
        }
        if (root.interfaceKinds.includes(kind)) root._playSample(kind);
        else Quickshell.execDetached(["canberra-gtk-play", "--id=" + root.soundFor[kind]]);
    }

    property Connections _focusTimer: Connections {
        target: FocusTimer
        function onCompleted() { root.play("focus-timer"); }
    }

    property Connections _notifications: Connections {
        target: Notifications
        function onPopupAdded(record) { if (record.urgency !== 0) root.play("notify"); }
    }
    property Connections _calendar: Connections {
        target: Calendar
        function onUpcomingAlertChanged() { if (Calendar.upcomingAlert && Config.showMeetingAlerts) root.play("meeting"); }
    }
    property Connections _bluetooth: Connections {
        target: Bluetooth
        function onLowBatteryAlertChanged() { if (Bluetooth.lowBatteryAlert && Config.showBatteryAlerts) root.play("battery"); }
        function onDeviceConnectionChanged(connected) { root.play(connected ? "device-added" : "device-removed"); }
    }

    // Pipewire reports the sink's volume as it binds at startup; that
    // isn't a change the user made. Dragging the Island's volume slider
    // isn't a key press either, so it stays quiet.
    property Timer _volumeSettle: Timer { interval: 3000; running: true }
    property PwObjectTracker _sinkTracker: PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    property Connections _volume: Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
        function onVolumeChanged() {
            if (root._volumeSettle.running || Pipewire.defaultAudioSink.audio.muted) return;
            if (IslandNavigation.open && IslandNavigation.destinationId === "volume") return;
            root.play("volume");
        }
    }

    property Connections _recorder: Connections {
        target: ScreenRecorder
        function onRecordingChanged() { root.play(ScreenRecorder.recording ? "recording-start" : "recording-stop"); }
    }

    property Connections _power: Connections {
        target: UPower
        function onOnBatteryChanged() { root.play(UPower.onBattery ? "power-unplug" : "power-plug"); }
    }

    // RemovableDrives runs a watcher process, so it's only started while
    // interface sounds are on.
    property Connections _drives: Connections {
        target: Config.interfaceSounds ? RemovableDrives : null
        function onDriveAdded() { root.play("device-added"); }
        function onDriveRemoved() { root.play("device-removed"); }
    }
}
