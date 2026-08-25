import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

// Custom tray right-click menu — replaces the native QMenu display() with
// our own styled QML popup matching the shell's visual language. Lives as a
// top-level PanelWindow (same pattern as Launcher/PowerMenu) to avoid the
// PopupWindow-as-child nesting blocker in Quickshell 0.3.1.
//
// Full-screen transparent Overlay surface — only the menu card itself is
// visible, positioned at the click coordinates Bridge provides. Click
// anywhere outside the card dismisses it (via the background MouseArea).
// Supports recursive submenus: a row with hasChildren opens a nested level.
PanelWindow {
    id: trayMenu

    visible: Bridge.trayMenuOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:traymenu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    // Track which submenu is open at this top level — only one chain at a
    // time. Each TrayMenuLevel manages its own children recursively.
    property var activeSubmenuHandle: null

    onVisibleChanged: {
        if (!visible) activeSubmenuHandle = null;
    }

    // Click-outside dismisses
    MouseArea {
        anchors.fill: parent
        onClicked: Bridge.closeTrayMenu()
    }

    // Escape key dismisses
    Item {
        anchors.fill: parent
        focus: trayMenu.visible
        Keys.onEscapePressed: Bridge.closeTrayMenu()
    }

    // Root menu level — positioned at the click point
    TrayMenuLevel {
        id: rootLevel
        menuHandle: Bridge.trayMenuHandle
        // Position near the click, clamped to stay on-screen
        x: Math.min(Bridge.trayMenuX, trayMenu.width - width - 8)
        y: Math.min(Bridge.trayMenuY, trayMenu.height - height - 8)
        onLeafTriggered: Bridge.closeTrayMenu()
    }
}
