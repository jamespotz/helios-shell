import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    property var sounds: AlertSounds
    property IconButton button: IconButton { icon: "close" }
    property Toggle toggle: Toggle {}
    property Slider slider: Slider { value: 0.32 }
    property LabeledNumberField field: LabeledNumberField { value: 5 }
    property FileView calls: FileView { path: Quickshell.env("HELIOS_SOUND_CALLS"); blockLoading: true }
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    Timer {
        interval: 150
        running: true
        onTriggered: {
            // Off by default: nothing plays.
            AlertSounds.play("volume");
            AlertSounds.play("device-added");
            Config.setOption("interfaceSounds", true);
            // Held volume key: repeats inside the throttle window play once.
            AlertSounds.play("volume");
            AlertSounds.play("volume");
            AlertSounds.play("volume");
            ScreenRecorder.recording = true;
            // Controls: a press taps, a toggle flips, a slider ticks only
            // when it crosses a tenth (0.32 -> 0.34 doesn't, -> 0.36 does).
            button.clicked();
            toggle.toggled(true);
            slider._move(0.34);
            slider._move(0.36);
            AlertSounds.play("unknown-kind");
            check.start();
        }
    }
    Timer {
        id: check
        interval: 300
        onTriggered: {
            calls.reload();
            // Interface sounds play from the sample cache; uploads aren't plays.
            const got = calls.text().trim().split("\n").filter(l => l.startsWith("play-sample ")).sort().join(",");
            const want = ["helios-volume", "helios-recording-start", "helios-tap", "helios-toggle-on", "helios-tick"]
                .map(name => "play-sample " + name).sort().join(",");
            if (got === want) console.warn("INTERFACE_SOUNDS_TEST_PASS");
            else console.error("INTERFACE_SOUNDS_TEST_FAIL", got);
            terminator.running = true;
        }
    }
}
