pragma Singleton
import QtQuick

QtObject {
    property bool launcherOpen: false
    property bool powerMenuOpen: false
    property bool keybindsOpen: false

    // Dynamic island: each screen's bar is itself the island. islandScreen +
    // islandTab pick which screen's bar is pinned open and to which panel
    // ("volume", "bluetooth", "wifi", "media") — the bar morphs shape between
    // them instead of opening a separate popup.
    property bool islandOpen: false
    property string islandScreen: ""
    property string islandTab: "volume"

    property bool liquidGlassEnabled: false
    property bool dndEnabled: false

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

    function toggleLauncher() { launcherOpen = !launcherOpen }
    function toggleLauncherOff() { launcherOpen = false }
    function togglePowerMenu() { powerMenuOpen = !powerMenuOpen }
    function closePowerMenu() { powerMenuOpen = false }
    function toggleKeybinds() { keybindsOpen = !keybindsOpen }
    function closeKeybinds() { keybindsOpen = false }
    function lock() { lockRequested() }

    function toggleIsland(screenName, tab) {
        if (islandOpen && islandScreen === screenName && islandTab === tab) {
            islandOpen = false;
            return;
        }
        islandScreen = screenName;
        islandTab = tab;
        islandOpen = true;
    }
    function setIslandTab(tab) { islandTab = tab }
    function closeIsland() { islandOpen = false }
    function toggleLiquidGlass() { liquidGlassEnabled = !liquidGlassEnabled }
}
