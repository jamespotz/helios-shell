pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property bool locked: false

    property bool dndEnabled: false

    // Settings window — a separate top-level surface from the island (see
    // SettingsWindow.qml). settingsPage remembers the last page shown so
    // reopening returns to where the user left off.
    property bool settingsOpen: false
    property string settingsScreen: ""
    property string settingsPage: "appearance"

    // The avatar file picker (zenity) is a plain toplevel; settingsOpen's
    // Overlay-layer surface always renders above it, so it'd be unclickable
    // underneath. SettingsWindow hides itself while this is true.
    property bool avatarPickerOpen: false

    function openSettings(screenName, page) {
        settingsScreen = screenName;
        if (page) settingsPage = page;
        settingsOpen = true;
    }
    function closeSettings() { settingsOpen = false }
    function toggleSettings(screenName, page) {
        if (settingsOpen && settingsScreen === screenName) {
            settingsOpen = false;
            return;
        }
        openSettings(screenName, page);
    }

    // Custom tray right-click menu — replaces the native QMenu display()
    // with our own styled QML popup. Tray.qml sets these on right-click;
    // TrayMenu.qml (a top-level PanelWindow) reads them to show/position
    // itself. trayMenuOpen is the single source of truth for whether the
    // menu is visible — Bar.qml uses it instead of the old cooldown hack.
    property bool trayMenuOpen: false
    property var trayMenuHandle: null
    property string trayMenuScreen: ""
    property real trayMenuX: 0
    property real trayMenuY: 0

    function openTrayMenu(menuHandle, screenName, globalX, globalY) {
        trayMenuHandle = menuHandle;
        trayMenuScreen = screenName;
        trayMenuX = globalX;
        trayMenuY = globalY;
        trayMenuOpen = true;
    }
    function closeTrayMenu() {
        trayMenuOpen = false;
        trayMenuHandle = null;
    }

    signal lockRequested()

    function toggleDnd() { dndEnabled = !dndEnabled }

    function lock() { lockRequested() }

    function toggleLiquidGlass() { liquidGlassEnabled = !liquidGlassEnabled }

    // --- Persisted: liquid glass preference ---------------------------------
    // Unlike the rest of this singleton (which is deliberately session-only
    // UI state — open panels, tray menu position, etc.), liquid glass is a
    // user preference like NightLight.enabled/IdleInhibit.enabled, so it
    // should survive a shell restart.
    //
    // Aliased straight to the JsonAdapter's own property rather than mirrored
    // into a plain `property bool` restored in Component.onCompleted: FileView
    // loads from disk *asynchronously* unless preload+blockLoading are set,
    // so a Component.onCompleted snapshot reads the adapter's compiled-in
    // default (false) before the real value has loaded — which is exactly
    // why the mirrored version kept resetting on every restart even though
    // the file itself was being written correctly. An alias has no such
    // race: it always reflects whatever the adapter currently holds, and
    // updates on its own the instant the async load actually lands.
    property alias liquidGlassEnabled: liquidGlassAdapter.enabled

    property FileView liquidGlassFile: FileView {
        path: Quickshell.statePath("liquid-glass.json")
        watchChanges: true

        JsonAdapter {
            id: liquidGlassAdapter
            property bool enabled: false
        }
    }

    onLiquidGlassEnabledChanged: root.liquidGlassFile.writeAdapter()
}
