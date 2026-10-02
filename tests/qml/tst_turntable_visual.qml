import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    id: root
    property int phase: 0
    property real firstAngle: 0
    property real firstArmAngle: 0
    property real baseWidth: 0
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer finish: Timer { interval: 100; onTriggered: root.terminator.running = true }
    function verify(value, message) { if (!value) throw new Error(message); }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.data || item.children || []) { const result = root.find(child, name); if (result) return result; }
        return null;
    }
    FloatingWindow {
        visible: true
        implicitWidth: 450
        implicitHeight: 400
        color: Colors.background
        Item {
            id: surface
            anchors.fill: parent
            Turntable { id: turntable; anchors.centerIn: parent; size: 160; playing: true; progress: 0.2 }
        }
    }
    Timer {
        id: advance
        interval: 350
        running: true
        onTriggered: {
            try {
                const record = root.find(turntable, "turntableRecord");
                const motion = root.find(turntable, "turntableMotion");
                const arm = root.find(turntable, "turntableTonearm");
                switch (root.phase) {
                case 0:
                    root.verify(turntable.width === turntable.height, "reference uses a square base");
                    root.baseWidth = turntable.width;
                    root.verify(record && motion && arm, "record, motion and arm present");
                    root.verify(record.color.toString() === "#101211" && !record.gradient, "default platter remains black and solid");
                    root.firstAngle = record.rotation;
                    Config.setOption("turntableScale", 120);
                    Config.setOption("turntableArtworkSize", 72);
                    Config.setOption("turntablePlatter", "sage");
                    break;
                case 1:
                    root.verify(record.color.toString() === "#8da58b" && !record.gradient, "solid preset updates platter");
                    Config.setOption("turntablePlatter", "sunset");
                    root.verify(Math.abs(turntable.width / root.baseWidth - 1.2) < 0.001, "scale updates layout dimensions");
                    root.verify(Math.abs(root.find(turntable, "turntableArtwork").width / record.width - 0.72) < 0.001, "artwork size follows setting");
                    root.verify(record.rotation !== root.firstAngle && motion.running, "record turns during playback");
                    Config.setOption("turntableSpin", false);
                    break;
                case 2:
                    root.verify(record.gradient && record.gradient.stops[0].color.toString() === "#e7aa76"
                        && record.gradient.stops[1].color.toString() === "#b76f91", "gradient preset updates both platter colors");
                    Config.setOption("turntablePlatter", "black");
                    root.verify(!motion.running, "rotation toggle stops frame work");
                    root.firstAngle = record.rotation;
                    Config.setOption("turntableSpin", true);
                    Config.setOption("reducedMotion", true);
                    break;
                case 3:
                    root.verify(record.color.toString() === "#101211" && !record.gradient, "switching back removes gradient");
                    root.verify(!motion.running && record.rotation === root.firstAngle, "Reduce motion overrides rotation setting");
                    Config.setOption("turntableTrackProgress", false);
                    root.firstArmAngle = arm.rotation;
                    turntable.progress = 0.9;
                    break;
                case 4:
                    root.verify(arm.rotation === root.firstArmAngle, "tracking off fixes arm at lead-in");
                    Config.setOption("turntableTrackProgress", true);
                    break;
                case 5:
                    root.verify(arm.rotation !== root.firstArmAngle, "arm tracks playback position");
                    Config.setOption("turntableTonearm", false);
                    break;
                case 6:
                    root.verify(!arm.visible && !root.find(turntable, "turntablePivot").visible, "tonearm toggle hides arm and pivot");
                    Config.setOption("turntableTonearm", true);
                    turntable.visible = false;
                    Config.setOption("reducedMotion", false);
                    break;
                case 7:
                    root.verify(!motion.running, "hidden Turntable does no frame work");
                    turntable.visible = true;
                    Config.setOption("turntableSpeed", "45");
                    Config.setOption("turntableFinish", "theme");
                    break;
                case 8:
                    root.verify(turntable.rpm === 45, "speed preference applied");
                    root.verify(root.find(turntable, "turntableBase").color.toString() === Colors.surfaceHigh.toString(), "theme finish follows palette");
                    Config.setOption("turntableFinish", "cream");
                    Config.setOption("turntableDesign", "sleeve");
                    break;
                case 9:
                    root.verify(root.find(turntable, "turntableSleeveArtwork").visible, "Sleeve artwork appears during playback");
                    root.verify(root.find(turntable, "turntableArtwork").color.toString() === "#e9e6df", "Sleeve label follows selected finish");
                    root.firstAngle = record.rotation;
                    break;
                case 10:
                    root.verify(record.rotation !== root.firstAngle && motion.running, "Sleeve vinyl spins during playback");
                    root.verify(root.find(turntable, "turntableSleeveArtwork").rotation === 0, "album sleeve does not rotate with vinyl");
                    Colors.text = "#3c3836";
                    Config.setOption("turntableFinish", "charcoal");
                    break;
                case 11:
                    const label = root.find(turntable, "turntableArtwork");
                    const labelIcon = label.children.find(child => child.icon === "music_note");
                    root.verify(labelIcon.color.toString() === "#b7b7b4", "charcoal label keeps light ink in light themes");
                    Config.setOption("turntableFinish", "theme");
                    break;
                case 12:
                    const themedLabel = root.find(turntable, "turntableArtwork");
                    const themedIcon = themedLabel.children.find(child => child.icon === "music_note");
                    root.verify(themedIcon.color.toString() === Colors.text.toString(), "Theme label ink follows theme");
                    if (Quickshell.env("HELIOS_TURNTABLE_CAPTURE")) {
                        surface.grabToImage(result => {
                            result.saveToFile(Quickshell.env("HELIOS_TURNTABLE_CAPTURE"));
                            console.warn("TURNTABLE_VISUAL_TEST_PASS"); root.finish.start();
                        });
                    } else { console.warn("TURNTABLE_VISUAL_TEST_PASS"); root.finish.start(); }
                    return;
                }
                root.phase++;
                advance.restart();
            } catch (error) { console.error("TURNTABLE_VISUAL_TEST_FAIL", error.toString()); root.finish.start(); }
        }
    }
}
