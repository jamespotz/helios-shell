pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    readonly property var destinations: [
        root._destination("drives", qsTr("Drives"), "DrivesDestination.qml", 560),
        root._destination("volume", "Volume", "VolumeDestination.qml"),
        root._destination("mixer", "Audio Mixer", "AudioMixerDestination.qml"),
        root._destination("bluetooth", "Bluetooth", "BluetoothDestination.qml"),
        root._destination("wifi", "Wi-Fi", "WifiDestination.qml"),
        root._destination("focus", "Focus Modes", "FocusDestination.qml"),
        root._destination("privacy", "Privacy", "PrivacyDestination.qml"),
        root._destination("automation", "Automations", "AutomationDestination.qml"),
        root._destination("media", "Media", "MediaDestination.qml"),
        root._destination("clipboard", "Clipboard", "ClipboardDestination.qml"),
        root._destination("recorder", "Screen Recorder", "ScreenRecorderDestination.qml"),
        root._destination("screenshot", "Screenshot", "ScreenshotDestination.qml"),
        root._destination("weather", "Weather", "WeatherDestination.qml"),
        root._destination("calendar", "Calendar", "CalendarDestination.qml"),
        root._destination("system", "System Monitor", "SystemMonitorDestination.qml"),
        root._destination("notifications", "Notifications", "NotificationHistoryDestination.qml"),
        root._destination("github", "GitHub", "GitHubDestination.qml"),
        root._destination("nightlight", "Night Light", "NightLightDestination.qml"),
        root._destination("display", "Displays", "DisplayDestination.qml"),
        root._destination("idlelock", "Idle & Lock", "IdleDestination.qml"),
        root._destination("wallpaper", "Wallpaper", "WallpaperDestination.qml"),
        root._destination("theme", "Theme", "ThemeDestination.qml"),
        root._destination("power", "Power mode", "PowerDestination.qml"),
        root._destination("powermenu", "Power", "PowerMenuDestination.qml"),
        root._destination("keybinds", "Keybinds", "KeybindsDestination.qml")
    ].concat(root.satellites.map(s => root._destination(s.id, s.destinationLabel || s.label, s.file, 0, s.inIsland ? "" : s.id)), [
        root._destination("annotate", "Annotate", "AnnotateDestination.qml", 0, "", true),
        root._destination("colorpicker", "Color Picker", "ColorPickerDestination.qml", 0, "", true),
        root._destination("launcher", "Launcher", "LauncherDestination.qml")
    ])

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

    // Each Satellite owns its Island destination; `destinations` derives them.
    // destinationLabel names it where the badge label would clash (Launcher).
    // inIsland opens the destination in the Island instead of the Satellite.
    // icon, color and badge feed the collapsed badge; each is a value or a
    // function. color defaults to the accent, badge text replaces the icon.
    // badgeFile replaces the whole badge with a component from modules/island.
    // card: "plain" shows the destination on its own card, without the
    // shared host's chrome.
    readonly property var satellites: [
        { id: "recording", label: qsTr("Recording"), file: "RecordingDestination.qml", card: "plain", badgeFile: "RecordingBadge.qml", onRight: false, active: () => ScreenRecorder.recording },
        { id: "privacy-status", label: qsTr("Privacy"), destinationLabel: "Privacy activity", file: "PrivacyStatusDestination.qml", onRight: false,
            icon: () => CameraActivity.isSystemCameraActive ? "videocam" : "mic", color: () => Colors.danger, active: () => MicActivity.isSystemMicActive || CameraActivity.isSystemCameraActive },
        { id: "focus-timer", label: qsTr("Focus timer"), file: "FocusTimerDestination.qml", badgeFile: "FocusTimerBadge.qml", inIsland: true, onRight: false, active: () => FocusTimer.active },
        { id: "meeting", label: qsTr("Upcoming meeting"), file: "MeetingDestination.qml", onRight: true, alertScoped: true,
            icon: "event", badge: () => Calendar.upcomingAlert ? qsTr("%1m").arg(Calendar.upcomingMinutesUntil) : "", enabled: () => Config.showMeetingAlerts, active: () => Calendar.upcomingAlert !== null },
        { id: "tasks", label: qsTr("Background tasks"), file: "TasksDestination.qml", onRight: true, alertScoped: true,
            icon: () => root._tasksFailed() ? "error" : "sync", color: () => root._tasksFailed() ? Colors.danger : Colors.accent,
            badge: () => Tasks.items.length > 1 ? String(Tasks.items.length)
                : Tasks.items.length === 1 && Tasks.items[0].status === "running" && Tasks.items[0].progress >= 0
                    ? Math.round(Math.max(0, Math.min(1, Tasks.items[0].progress)) * 100) + "%" : "", enabled: () => Config.showTaskAlerts, active: () => Tasks.items.length > 0 },
        { id: "maintenance", label: qsTr("Maintenance"), file: "MaintenanceDestination.qml", onRight: true,
            icon: () => root._maintenanceFailed() ? "error" : "download", color: () => root._maintenanceFailed() ? Colors.danger : Colors.accent, active: () => Maintenance.hasAlert },
        { id: "focus-status", label: qsTr("Focus mode"), destinationLabel: "Active focus mode", file: "FocusStatusDestination.qml", onRight: true, icon: "center_focus_strong", active: () => FocusModes.activeId.length > 0 },
        { id: "gamemode", label: qsTr("Game Mode"), file: "GameModeDestination.qml", onRight: true, icon: "sports_esports", active: () => GameMode.enabled },
        { id: "caffeine", label: qsTr("Caffeine"), file: "CaffeineDestination.qml", onRight: true, icon: "coffee", color: () => Colors.warning, active: () => IdleInhibit.inhibited }
    ]

    // Whether an alert or Satellite entry shows: enabled in Settings and active.
    function shows(entry) { return (!entry.enabled || entry.enabled()) && entry.active(); }

    // Whether the user allows an alert (by mode) or Satellite (by id);
    // AlertSounds asks this so a hidden alert stays silent too.
    function alertEnabled(id) {
        const entry = root._alerts.find(a => a.mode === id) || root.satellites.find(s => s.id === id);
        return !!entry && (!entry.enabled || entry.enabled());
    }

    function _tasksFailed() { return Tasks.items.some(t => t.status === "error") }
    function _maintenanceFailed() { return Maintenance.rebootRequired || Maintenance.failedUnits.length > 0 }

    // Catalogue order is priority. Each side owns one slot; an expanded
    // destination stays pinned while other activities change underneath it.
    function satellitesFor(screenName, onRight) {
        return root.satellites.filter(s => s.onRight === onRight && root.shows(s)
            && (!s.alertScoped || root._alertsOn(screenName, Config.alertScreen, root._focusedScreen, root._alertScreens)));
    }

    function satelliteFor(screenName, onRight) {
        if (root.satelliteOpenFor(screenName)) {
            const selected = root.satellites.find(s => s.id === root.satelliteId && s.onRight === onRight);
            if (selected) return selected;
        }
        return root.satellitesFor(screenName, onRight)[0] || null;
    }

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

    // Alert priority, highest first: the first entry that shows wins.
    // enabled is the user's setting for that alert (omitted when it has
    // none); dismiss is omitted where dismissing that mode isn't supported.
    readonly property var _alerts: [
        {
            mode: "notify",
            card: "NotificationCard.qml",
            active: () => Notifications.state.popups.length > 0,
            dismiss: () => Notifications.dismissAll()
        },
        {
            mode: "github",
            card: "GitHubCard.qml",
            active: () => GitHub.popups.length > 0,
            dismiss: () => GitHub.hideAllPopups()
        },
        {
            mode: "battery",
            card: "BatteryAlertCard.qml",
            enabled: () => Config.showBatteryAlerts,
            active: () => Bluetooth.lowBatteryAlert !== null,
            dismiss: () => Bluetooth.dismissLowBattery()
        },
        { mode: "focus-timer", card: "FocusTimerCard.qml", active: () => FocusTimer.completionPending, dismiss: () => FocusTimer.dismissCompletion() }
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
            ? root._alerts.find(a => root.shows(a)) : null;
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

    // The alert card file for a mode, or "" when the mode isn't an alert.
    function alertCardFor(mode) {
        const alert = root._alerts.find(a => a.mode === mode);
        return alert ? Qt.resolvedUrl("../modules/island/" + alert.card) : "";
    }

    function _destination(id, label, file, maxHeight, satelliteId, retainOnFocusLoss) {
        return {
            id: id,
            label: label,
            source: Qt.resolvedUrl("../modules/island/" + file),
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
