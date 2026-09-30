pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property var destinations: [root._destination("volume", "Volume", "VolumeIsland.qml"), root._destination("mixer", "Audio Mixer", "AudioMixerIsland.qml"), root._destination("bluetooth", "Bluetooth", "BluetoothIsland.qml"), root._destination("wifi", "Wi-Fi", "WifiIsland.qml"), root._destination("focus", "Focus Modes", "FocusIsland.qml"), root._destination("privacy", "Privacy", "PrivacyIsland.qml"), root._destination("automation", "Automations", "AutomationIsland.qml"), root._destination("media", "Media", "MediaIsland.qml"), root._destination("clipboard", "Clipboard", "ClipboardIsland.qml"), root._destination("recorder", "Screen Recorder", "ScreenRecorderIsland.qml"), root._destination("screenshot", "Screenshot", "ScreenshotIsland.qml"), root._destination("weather", "Weather", "WeatherIsland.qml"), root._destination("calendar", "Calendar", "CalendarIsland.qml"), root._destination("system", "System Monitor", "SystemMonitorIsland.qml"), root._destination("notifications", "Notifications", "NotificationHistoryIsland.qml"), root._destination("nightlight", "Night Light", "NightLightIsland.qml"), root._destination("display", "Displays", "DisplayIsland.qml"), root._destination("idlelock", "Idle & Lock", "IdleIsland.qml"), root._destination("wallpaper", "Wallpaper", "WallpaperSettings.qml"), root._destination("theme", "Theme", "ThemeSettings.qml"), root._destination("power", "Power", "PowerIsland.qml"), root._destination("powermenu", "Power", "PowerMenuIsland.qml"), root._destination("keybinds", "Keybinds", "KeybindsIsland.qml"), root._destination("maintenance", "Maintenance", "MaintenanceIsland.qml", 0, "maintenance"), root._destination("recording", "Recording", "RecordingSatellite.qml", 0, "recording"), root._destination("annotate", "Annotate", "AnnotateToolbarIsland.qml", 0, "", true), root._destination("colorpicker", "Color Picker", "ColorPickerIsland.qml", 0, "", true), root._destination("launcher", "Launcher", "LauncherIsland.qml")]

    property bool _open: false
    property string _screen: ""
    property string _destinationId: "volume"

    readonly property bool open: root._open
    readonly property string screen: root._screen
    readonly property string destinationId: root._destinationId
    readonly property var current: root.resolve(root._destinationId)

    // Main and satellite selections are independent; only one satellite expands.
    property bool _satelliteOpen: false
    property string _satelliteScreen: ""
    property string _satelliteId: ""
    readonly property bool satelliteOpen: root._satelliteOpen
    readonly property string satelliteScreen: root._satelliteScreen
    readonly property string satelliteId: root._satelliteId

    readonly property var satellites: [
        { id: "recording", label: "Recording", onRight: false, active: () => ScreenRecorder.recording },
        { id: "maintenance", label: "Maintenance", onRight: true, active: () => Maintenance.hasAlert }
    ]

    signal rejected(string destinationId)

    function panelOpenFor(screenName) {
        const dest = root.resolve(root._destinationId);
        return root.open && root.screen === screenName && !(dest && dest.satelliteId);
    }

    function satelliteOpenFor(screenName, satelliteId) {
        return root.satelliteOpen && root.satelliteScreen === screenName
            && (!satelliteId || root.satelliteId === satelliteId);
    }

    function showSatellite(screenName, satelliteId) {
        const destination = root.resolve(satelliteId);
        if (!destination || !destination.available || !destination.satelliteId) {
            root.rejected(satelliteId);
            return false;
        }
        // Two focus grabs on different screens would compete for input.
        if (root.open && root.screen !== screenName) root.closeMain();
        root._satelliteScreen = screenName;
        root._satelliteId = satelliteId;
        root._satelliteOpen = true;
        return true;
    }

    function toggleSatellite(screenName, satelliteId) {
        if (root.satelliteOpenFor(screenName, satelliteId)) {
            root.closeSatellite(screenName);
            return true;
        }
        return root.showSatellite(screenName, satelliteId);
    }

    function closeSatellite(screenName) {
        if (!screenName || root.satelliteScreen === screenName) root._satelliteOpen = false;
    }

    function closeMain(screenName) {
        if (!screenName || root.screen === screenName) root._open = false;
    }

    function dismissOutside(screenName) {
        root.closeSatellite(screenName);
        if (root.dismissesOnFocusLoss(screenName)) root.closeMain(screenName);
    }

    // Alert priority, highest first: the first entry whose active() is true
    // wins. dismiss is omitted where dismissing that mode isn't supported.
    readonly property var _alerts: [
        {
            mode: "notify",
            active: () => Notifications.state.popups.length > 0,
            dismiss: () => Notifications.dismissAll()
        },
        {
            mode: "task",
            active: () => Config.showTaskAlerts && Tasks.items.length > 0
        },
        {
            mode: "meeting",
            active: () => Config.showMeetingAlerts && Calendar.upcomingAlert !== null,
            dismiss: () => Calendar.dismissAlert()
        },
        {
            mode: "battery",
            active: () => Config.showBatteryAlerts && Bluetooth.lowBatteryAlert !== null,
            dismiss: () => Bluetooth.dismissLowBattery()
        }
    ]

    // Which screens show alert cards (Settings > Island > Screens): "all",
    // "focused", or a screen name. When the target can't be resolved or its
    // island is off, every screen shows them, so alerts never vanish.
    readonly property var _alertScreens: Quickshell.screens.map(s => s.name).filter(name => Config.islandShownOn(name))
    readonly property string _focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""

    function _alertsOn(screenName, setting, focusedName, availableNames) {
        const target = setting === "focused" ? focusedName : setting;
        if (setting === "all" || !availableNames.includes(target)) return true;
        return screenName === target;
    }

    function modeFor(screenName, hovering) {
        if (root.panelOpenFor(screenName))
            return root.destinationId;
        const alert = root._alertsOn(screenName, Config.alertScreen, root._focusedScreen, root._alertScreens)
            ? root._alerts.find(a => a.active()) : null;
        if (alert)
            return alert.mode;
        return hovering ? "peek" : "idle";
    }

    function expandedFor(screenName, hovering) {
        return root.modeFor(screenName, hovering) !== "idle";
    }

    function dismissesOnFocusLoss(screenName) {
        const destination = root.current;
        return !root.panelOpenFor(screenName) || !destination || !destination.retainOnFocusLoss;
    }

    function dismiss(screenName, mode) {
        if (root.panelOpenFor(screenName)) {
            root.closeMain(screenName);
            return;
        }
        const alert = root._alerts.find(a => a.mode === mode);
        if (alert && alert.dismiss)
            alert.dismiss();
    }

    function _destination(id, label, file, maxHeight, satelliteId, retainOnFocusLoss) {
        return {
            id: id,
            label: label,
            source: Qt.resolvedUrl("../modules/bar/" + file),
            maxHeight: maxHeight || 0,
            available: true,
            satelliteId: satelliteId || "",
            retainOnFocusLoss: retainOnFocusLoss || false
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
        if (destination.satelliteId) return root.showSatellite(screenName, destination.id);
        if (root.satelliteOpen && root.satelliteScreen !== screenName) root.closeSatellite();
        root._screen = screenName;
        root._destinationId = destination.id;
        root._open = true;
        return true;
    }

    function toggle(screenName, destinationId) {
        const destination = root.resolve(destinationId);
        if (destination && destination.satelliteId) return root.toggleSatellite(screenName, destinationId);
        if (root._open && root._screen === screenName && root._destinationId === destinationId) {
            root.closeMain(screenName);
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
        if (destination.satelliteId) {
            if (!root.showSatellite(root.screen, destination.id)) return false;
            root.closeMain();
            return true;
        }
        root._destinationId = destination.id;
        return true;
    }

    function close() {
        root.closeMain();
        root.closeSatellite();
    }
}
