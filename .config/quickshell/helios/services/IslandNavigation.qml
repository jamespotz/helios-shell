pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property var destinations: [
        root._destination("volume", "Volume", "VolumeIsland.qml"),
        root._destination("mixer", "Audio Mixer", "AudioMixerIsland.qml"),
        root._destination("bluetooth", "Bluetooth", "BluetoothIsland.qml"),
        root._destination("wifi", "Wi-Fi", "WifiIsland.qml"),
        root._destination("focus", "Focus Modes", "FocusIsland.qml"),
        root._destination("privacy", "Privacy", "PrivacyIsland.qml"),
        root._destination("automation", "Automations", "AutomationIsland.qml"),
        root._destination("media", "Media", "MediaCard.qml"),
        root._destination("clipboard", "Clipboard", "ClipboardIsland.qml"),
        root._destination("recorder", "Screen Recorder", "ScreenRecorderIsland.qml"),
        root._destination("screenshot", "Screenshot", "ScreenshotIsland.qml"),
        root._destination("weather", "Weather", "WeatherPanel.qml"),
        root._destination("calendar", "Calendar", "CalendarIsland.qml"),
        root._destination("system", "System Monitor", "SystemMonitorIsland.qml"),
        root._destination("notifications", "Notifications", "NotificationHistoryIsland.qml"),
        root._destination("nightlight", "Night Light", "NightLightIsland.qml"),
        root._destination("display", "Displays", "DisplayIsland.qml"),
        root._destination("idlelock", "Idle & Lock", "IdleIsland.qml"),
        root._destination("wallpaper", "Wallpaper", "WallpaperSettings.qml"),
        root._destination("theme", "Theme", "ThemeSettings.qml"),
        root._destination("power", "Power", "PowerIsland.qml"),
        root._destination("powermenu", "Power", "PowerMenuIsland.qml"),
        root._destination("keybinds", "Keybinds", "KeybindsIsland.qml"),
        root._destination("launcher", "Launcher", "LauncherIsland.qml")
    ]

    property bool _open: false
    property string _screen: ""
    property string _destinationId: "volume"

    readonly property bool open: root._open
    readonly property string screen: root._screen
    readonly property string destinationId: root._destinationId
    readonly property var current: root.resolve(root._destinationId)

    signal rejected(string destinationId)

    function _destination(id, label, file, maxHeight) {
        return {
            id: id,
            label: label,
            source: Qt.resolvedUrl("../modules/bar/" + file),
            maxHeight: maxHeight || 0,
            available: true
        };
    }

    function resolve(destinationId) {
        return root.destinations.find(destination => destination.id === destinationId) || null;
    }

    function show(screenName, destinationId) {
        const destination = root.resolve(destinationId);
        if (!destination || !destination.available) {
            root.rejected(destinationId);
            return false;
        }
        root._screen = screenName;
        root._destinationId = destination.id;
        root._open = true;
        return true;
    }

    function toggle(screenName, destinationId) {
        if (root._open && root._screen === screenName && root._destinationId === destinationId) {
            root.close();
            return true;
        }
        return root.show(screenName, destinationId);
    }

    function select(destinationId) {
        const destination = root.resolve(destinationId);
        if (!destination || !destination.available) {
            root.rejected(destinationId);
            return false;
        }
        root._destinationId = destination.id;
        return true;
    }

    function close() { root._open = false; }
}
