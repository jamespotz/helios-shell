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

    // Fired every time a tray icon opens its native context menu — a signal,
    // not a bool, because there's no "menu closed" event to reset a flag
    // with, and a plain bool toggled on each right-click misses every other
    // click (QML only fires onXChanged on an actual value change, so
    // toggling true->false->true->... silently no-ops half the time, and
    // any click that would toggle true->true because a previous cycle never
    // got reset does too).
    signal trayMenuOpened()

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
