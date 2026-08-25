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
// Uses a full-screen transparent surface as a coordinate space (so the menu
// card can be positioned anywhere on screen with plain x/y), but does NOT
// block input to windows below — the surface is fully click-through via
// `mask` limited to just the menu card. HyprlandFocusGrab handles
// click-outside-to-close while letting the click reach whatever's below
// (other tray icons, desktop, etc).
PanelWindow {
    id: trayMenu

    visible: Bridge.trayMenuOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:traymenu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusiveZone: -1

    // Only the menu card itself receives input — everything else on this
    // surface is click-through, so tray icons and other windows below
    // remain interactive.
    mask: Region { item: rootLevel }

    // Focus grab for click-outside-to-close — the click still reaches
    // whatever's below (the Bar's tray icons), so right-clicking a
    // different icon seamlessly swaps the menu.
    HyprlandFocusGrab {
        id: menuFocusGrab
        windows: [trayMenu]
        active: trayMenu.visible
        onCleared: Bridge.closeTrayMenu()
    }

    // Escape key dismisses
    Item {
        anchors.fill: parent
        focus: trayMenu.visible
        Keys.onEscapePressed: Bridge.closeTrayMenu()
    }

    // Root menu level — positioned at the click point, clamped on-screen
    TrayMenuLevel {
        id: rootLevel
        menuHandle: Bridge.trayMenuHandle
        x: Math.min(Bridge.trayMenuX, trayMenu.width - width - 8)
        y: Math.min(Bridge.trayMenuY, trayMenu.height - height - 8)
        onLeafTriggered: Bridge.closeTrayMenu()
    }
}
