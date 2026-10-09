import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

PanelWindow {
    id: osd

    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property int shadowPadding: 24

    anchors { bottom: true }
    margins.bottom: 60 - shadowPadding
    implicitWidth: 260 + shadowPadding * 2
    implicitHeight: 56 + shadowPadding * 2
    color: "transparent"
    exclusiveZone: 0
    visible: shown

    property bool shown: false
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property string message: ""
    property string messageIcon: ""
    // Level kinds draw a bar; every other kind is a text toast.
    readonly property bool isMessage: kind !== "volume" && kind !== "brightness"

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    function show(newKind, newLevel, isMuted) {
        kind = newKind;
        level = Math.max(0, Math.min(1, newLevel));
        muted = !!isMuted;
        shown = true;
        hideTimer.restart();
    }

    // Text toast — no level bar — used by kinds like "bluetooth" that report
    // a one-off event instead of an adjustable value.
    function showMessage(newKind, text, icon) {
        kind = newKind;
        message = text;
        messageIcon = icon || "";
        shown = true;
        hideTimer.restart();
    }

    Connections {
        target: osd.sink ? osd.sink.audio : null
        function onVolumeChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
        function onMutedChanged() { osd.show("volume", osd.sink.audio.volume, osd.sink.audio.muted) }
    }

    Connections {
        target: Bluetooth
        function onDeviceAutoConnected(name) { osd.showMessage("bluetooth", name + " connected", "bluetooth_connected") }
    }

    Connections {
        target: osd.source ? osd.source.audio : null
        function onMutedChanged() {
            osd.showMessage("mic", osd.source.audio.muted ? "Microphone muted" : "Microphone on", osd.source.audio.muted ? "mic_off" : "mic")
        }
    }

    // UPower reports the current profile shortly after startup; that first
    // report isn't a change the user made, so skip it.
    Timer { id: profileSettle; interval: 3000; running: true }
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            if (profileSettle.running) return;
            const profile = PowerProfiles.profile;
            osd.showMessage("power", profile === PowerProfile.PowerSaver ? "Power Saver"
                : profile === PowerProfile.Performance ? "Performance" : "Balanced",
                profile === PowerProfile.PowerSaver ? "eco" : profile === PowerProfile.Performance ? "bolt" : "balance")
        }
    }

    // Text toasts carry words to read, so give them a bit longer on screen
    // than the volume/brightness level bars.
    Timer {
        id: hideTimer
        interval: osd.isMessage ? 2500 : 1500
        onTriggered: osd.shown = false
    }

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
        function toggleMicMute() {
            if (osd.source && osd.source.audio) osd.source.audio.muted = !osd.source.audio.muted;
        }
    }

    // SurfaceBackground's look (shadow, translucent surface, hairline border),
    // with the fill swapped for LiquidGlassSurface so the OSD follows the
    // same Liquid Glass toggle as the island.
    Rectangle {
        id: panel
        anchors.fill: parent
        anchors.margins: osd.shadowPadding
        radius: Colors.radiusLarge
        color: "transparent"
        border.width: 0.5
        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)

        // The shadow fills the panel's interior too, which darkens the
        // translucent glass tint — hide it with glass on so the OSD matches
        // the island's transparency.
        SurfaceShadow {
            anchors.fill: parent
            z: -1
            cornerRadius: panel.radius
            visible: !ShellState.liquidGlassEnabled
        }

        LiquidGlassSurface {
            anchors.fill: parent
            z: -1
            active: ShellState.liquidGlassEnabled
            cornerRadius: panel.radius
            fallbackColor: Qt.alpha(Colors.surface, Colors.panelOpacity)
        }

        Row {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: osd.isMessage ? osd.messageIcon
                    : osd.kind === "brightness" ? "brightness_6"
                    : osd.muted ? "volume_off"
                    : osd.level > 0.5 ? "volume_up" : "volume_down"
            }

            StyledText {
                visible: osd.isMessage
                width: parent.width - 30 - 12
                anchors.verticalCenter: parent.verticalCenter
                text: osd.message
                elide: Text.ElideRight
            }

            Rectangle {
                visible: !osd.isMessage
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
                    Behavior on width { enabled: !Config.reducedMotion; Spring {} }
                }
            }
        }
    }
}
