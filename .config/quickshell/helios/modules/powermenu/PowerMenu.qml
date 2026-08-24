import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../services"
import "../../services/Utils.js" as Utils
import "../../components"

PanelWindow {
    id: powerMenu

    visible: Bridge.powerMenuOpen
    screen: Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "helios:powermenu"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // -1, not 0: ignore the bar's exclusive-zone reservation so this
    // full-screen surface actually reaches the true top edge instead of
    // being shrunk away from it. Same fix as Wallpaper.qml.
    exclusiveZone: -1

    property string pendingAction: ""

    IpcHandler {
        target: "powermenu"
        function toggle() { Bridge.togglePowerMenu() }
    }

    onVisibleChanged: if (!visible) pendingAction = ""

    Item {
        anchors.fill: parent
        focus: powerMenu.visible
        Keys.onEscapePressed: Bridge.closePowerMenu()

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: powerMenu.visible ? 0.45 : 0
            Behavior on opacity { NumberAnimation { duration: Config.animMedium } }

            MouseArea {
                anchors.fill: parent
                onClicked: Bridge.closePowerMenu()
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 18

            PowerAction {
                icon: "lock"
                label: "Lock"
                onActivated: { Bridge.lock(); Bridge.closePowerMenu(); }
            }
            PowerAction {
                icon: "logout"
                label: "Logout"
                destructive: true
                armed: powerMenu.pendingAction === label
                onArmRequested: powerMenu.pendingAction = label
                // This machine's Hyprland runs a lua-config plugin that
                // wraps every `dispatch` payload as `hl.dispatch(<payload>)`
                // and evaluates it as Lua — a bare dispatcher name like
                // "exit" isn't valid Lua and fails silently (confirmed live:
                // `hyprctl dispatch exit` errors with "attempt to call a nil
                // value"). binds.lua already uses the working form for the
                // same dispatcher: hl.dsp.exit().
                onActivated: { Hyprland.dispatch("hl.dsp.exit()"); Bridge.closePowerMenu(); }
            }
            PowerAction {
                icon: "dark_mode"
                label: "Suspend"
                onActivated: { Quickshell.execDetached(["systemctl", "suspend"]); Bridge.closePowerMenu(); }
            }
            PowerAction {
                icon: "restart_alt"
                label: "Reboot"
                destructive: true
                armed: powerMenu.pendingAction === label
                onArmRequested: powerMenu.pendingAction = label
                onActivated: { Quickshell.execDetached(["systemctl", "reboot"]); Bridge.closePowerMenu(); }
            }
            PowerAction {
                icon: "power_settings_new"
                label: "Shutdown"
                destructive: true
                armed: powerMenu.pendingAction === label
                onArmRequested: powerMenu.pendingAction = label
                onActivated: { Quickshell.execDetached(["systemctl", "poweroff"]); Bridge.closePowerMenu(); }
            }
        }
    }
}
