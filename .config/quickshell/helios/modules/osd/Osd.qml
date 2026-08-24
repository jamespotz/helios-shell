import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

PanelWindow {
    id: osd

    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { bottom: true }
    margins.bottom: 60
    implicitWidth: 260
    implicitHeight: 56
    color: "transparent"
    exclusiveZone: 0
    visible: hideTimer.running

    property string kind: "volume"
    property real level: 0
    property bool muted: false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink

    function show(newKind, newLevel, isMuted) {
        kind = newKind;
        level = Math.max(0, Math.min(1, newLevel));
        muted = !!isMuted;
        hideTimer.restart();
    }

    Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumeChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
        function onMutedChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
    }

    Timer { id: hideTimer; interval: 1500 }

    Process {
        id: brightnessGet
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length >= 4) {
                    const pct = parseInt(parts[3].replace("%", ""), 10) / 100;
                    osd.show("brightness", pct, false);
                }
            }
        }
    }

    function adjustBrightness(delta) {
        Quickshell.execDetached(["brightnessctl", "set", (delta >= 0 ? "+" : "") + delta + "%"]);
        brightnessGet.running = false;
        brightnessGet.running = true;
    }

    IpcHandler {
        target: "osd"
        function volumeUp() {
            if (osd.sink && osd.sink.audio) osd.sink.audio.volume = Math.min(1, osd.sink.audio.volume + 0.05);
        }
        function volumeDown() {
            if (osd.sink && osd.sink.audio) osd.sink.audio.volume = Math.max(0, osd.sink.audio.volume - 0.05);
        }
        function toggleMute() {
            if (osd.sink && osd.sink.audio) osd.sink.audio.muted = !osd.sink.audio.muted;
        }
        function brightnessUp() { osd.adjustBrightness(5) }
        function brightnessDown() { osd.adjustBrightness(-5) }
    }

    PanelBackground {
        anchors.fill: parent

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: osd.kind === "brightness" ? "brightness_6"
                    : osd.muted ? "volume_off"
                    : osd.level > 0.5 ? "volume_up" : "volume_down"
            }

            Rectangle {
                width: parent.width - 30 - 12
                height: 6
                radius: 3
                color: Colors.surfaceHigh
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: parent.width * (osd.muted ? 0 : osd.level)
                    height: parent.height
                    radius: parent.radius
                    color: Colors.accent
                    Behavior on width { NumberAnimation { duration: Config.animFast } }
                }
            }
        }
    }
}
