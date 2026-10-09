import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "services"
import "components"
import "modules/island" as IslandUI

ShellRoot {
    id: root
    TestCase { id: input; name: "AudioMixerStreams"; when: false }
    property var originalSlider: null
    property int phase: 0
    property int attempts: 0
    property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    property Process playback: Process {
        command: ["pw-cat", "--playback", "--raw", "--sample-count", "480000",
            "--properties", 'application.name="Helios mixer regression"', "/dev/zero"]
        running: true
    }
    property Process tick: Process {
        command: ["pw-cat", "--playback", "--raw", "--sample-count", "24000",
            "--properties", 'application.name="Helios transient regression" media.name="helios-tick"', "/dev/zero"]
    }
    function sliderFor(item, name) {
        if (item.modelData && item.modelData.properties && item.modelData.properties["application.name"] === name) {
            const found = findSlider(item);
            if (found) return found;
        }
        for (const child of item.children || []) {
            const found = sliderFor(child, name);
            if (found) return found;
        }
        return null;
    }
    function findSlider(item) {
        if (item.fraction !== undefined && item.moved) return item;
        for (const child of item.children || []) {
            const found = findSlider(child);
            if (found) return found;
        }
        return null;
    }
    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 500
        IslandUI.AudioMixerDestination { id: mixer; width: 340 }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            try {
                if (phase === 0) {
                    root.originalSlider = root.sliderFor(mixer, "Helios mixer regression");
                    if (!root.originalSlider) {
                        if (++root.attempts > 30) throw new Error("test playback did not appear");
                        return;
                    }
                    input.mousePress(root.originalSlider, root.originalSlider.width * 0.3, 12);
                    input.mouseMove(root.originalSlider, root.originalSlider.width * 0.6, 12);
                    tick.running = true;
                    attempts = 0;
                    phase = 1;
                    return;
                }
                if (phase === 1) {
                    if (!Pipewire.nodes.values.some(n => n.properties && n.properties["application.name"] === "Helios transient regression")) {
                        if (++attempts > 30) throw new Error("transient playback did not appear");
                        return;
                    }
                    if (root.sliderFor(mixer, "Helios mixer regression") !== root.originalSlider)
                        throw new Error("temporary sound recreated app slider during drag");
                    if (Math.abs(root.originalSlider.fraction - 0.6) > 0.01)
                        throw new Error("temporary sound interrupted pointer tracking");
                    if (root.sliderFor(mixer, "Helios transient regression"))
                        throw new Error("interface tick shown as an app");
                    phase = 2;
                    return;
                }
                if (tick.running) return;
                if (root.sliderFor(mixer, "Helios mixer regression") !== root.originalSlider)
                    throw new Error("temporary sound removal recreated app slider");
                if (Math.abs(root.originalSlider.fraction - 0.6) > 0.01)
                    throw new Error("sound removal interrupted pointer tracking");
                input.mouseRelease(root.originalSlider, root.originalSlider.width * 0.6, 12);
                console.warn("AUDIO_MIXER_STREAMS_TEST_PASS");
            } catch (error) {
                console.error("AUDIO_MIXER_STREAMS_TEST_FAIL", error.toString());
            }
            playback.running = false;
            tick.running = false;
            terminator.running = true;
        }
    }
}
