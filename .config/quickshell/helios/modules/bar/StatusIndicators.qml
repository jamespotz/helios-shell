import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import "../../services"
import "../../components"

// Apple-style status indicators row — tighter spacing (4px), consistent
// icon sizing, and clean active states. Icons use a slightly reduced
// opacity when inactive for visual hierarchy.
Row {
    id: root
    spacing: 4

    required property var targetScreen

    function isIslandTab(tab) {
        return Bridge.islandOpen && Bridge.islandScreen === root.targetScreen.name && Bridge.islandTab === tab;
    }
    function openIslandTab(tab) {
        Bridge.toggleIsland(root.targetScreen.name, tab);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : true

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery && battery.isPresent

    readonly property bool bluetoothConnected: {
        const devices = Bluetooth.devices ? Bluetooth.devices.values : [];
        return devices.some(d => d.connected);
    }

    readonly property bool hasActiveMedia: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.some(p => p.isPlaying);
    }

    IconButton {
        visible: root.hasActiveMedia
        icon: "music_note"
        active: root.isIslandTab("media")
        onClicked: root.openIslandTab("media")
    }

    IconButton {
        visible: MicActivity.isSystemMicActive
        icon: "mic"
        active: root.isIslandTab("volume")
        onClicked: root.openIslandTab("volume")
    }

    IconButton {
        icon: root.muted ? "volume_off"
            : root.volume > 0.5 ? "volume_up"
            : root.volume > 0 ? "volume_down" : "volume_mute"
        active: root.isIslandTab("volume")
        onClicked: root.openIslandTab("volume")
    }

    IconButton {
        icon: root.bluetoothConnected ? "bluetooth_connected"
            : (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled) ? "bluetooth" : "bluetooth_disabled"
        active: root.isIslandTab("bluetooth")
        onClicked: root.openIslandTab("bluetooth")
    }

    IconButton {
        icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "eco"
            : PowerProfiles.profile === PowerProfile.Performance ? "bolt" : "balance"
        active: root.isIslandTab("power")
        onClicked: root.openIslandTab("power")
    }

    IconButton {
        visible: root.hasBattery
        icon: {
            const b = root.battery;
            if (!b) return "battery_unknown";
            if (b.state === UPowerDeviceState.Charging || b.state === UPowerDeviceState.PendingCharge)
                return "battery_charging_full";
            const p = b.percentage * 100;
            if (p >= 95) return "battery_full";
            if (p >= 80) return "battery_6_bar";
            if (p >= 60) return "battery_5_bar";
            if (p >= 40) return "battery_4_bar";
            if (p >= 20) return "battery_3_bar";
            return "battery_alert";
        }
    }

    IconButton {
        icon: {
            switch (Networking.connectivity) {
            case NetworkConnectivity.Full: return "wifi";
            case NetworkConnectivity.Portal:
            case NetworkConnectivity.Limited: return "wifi_notification";
            case NetworkConnectivity.None: return "wifi_off";
            default: return "wifi_off";
            }
        }
        active: root.isIslandTab("wifi")
        onClicked: root.openIslandTab("wifi")
    }

    IconButton {
        icon: ScreenRecorder.recording ? "stop_circle" : "videocam"
        active: ScreenRecorder.recording || root.isIslandTab("recorder")
        onClicked: root.openIslandTab("recorder")
    }

    IconButton {
        icon: "auto_awesome"
        active: Bridge.liquidGlassEnabled
        onClicked: Bridge.toggleLiquidGlass()
    }

    // Thin separator before system actions
    Rectangle {
        width: 1
        height: 14
        radius: 0.5
        color: Colors.overlay
        opacity: 0.3
        anchors.verticalCenter: parent.verticalCenter
    }

    IconButton {
        icon: "settings"
        active: root.isIslandTab("island")
        onClicked: root.openIslandTab("island")
    }

    IconButton {
        icon: "power_settings_new"
        active: Bridge.powerMenuOpen
        onClicked: Bridge.togglePowerMenu()
    }
}
