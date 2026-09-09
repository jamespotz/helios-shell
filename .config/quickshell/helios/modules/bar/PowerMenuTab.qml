import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../services"
import "../../components"

Item {
    id: root

    property string pendingAction: ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: 18

        PowerAction {
            icon: "lock"
            label: "Lock"
            onActivated: { Bridge.lock(); IslandNavigation.close(); }
        }
        PowerAction {
            icon: "logout"
            label: "Logout"
            destructive: true
            armed: root.pendingAction === label
            onArmRequested: root.pendingAction = label
            // This machine's Hyprland runs a lua-config plugin that wraps
            // every `dispatch` payload as `hl.dispatch(<payload>)` and
            // evaluates it as Lua — a bare dispatcher name like "exit" isn't
            // valid Lua and fails silently. binds.lua already uses the
            // working form for the same dispatcher: hl.dsp.exit().
            onActivated: { Hyprland.dispatch("hl.dsp.exit()"); IslandNavigation.close(); }
        }
        PowerAction {
            icon: "dark_mode"
            label: "Suspend"
            onActivated: { Quickshell.execDetached(["systemctl", "suspend"]); IslandNavigation.close(); }
        }
        PowerAction {
            icon: "restart_alt"
            label: "Reboot"
            destructive: true
            armed: root.pendingAction === label
            onArmRequested: root.pendingAction = label
            onActivated: { Quickshell.execDetached(["systemctl", "reboot"]); IslandNavigation.close(); }
        }
        PowerAction {
            icon: "power_settings_new"
            label: "Shutdown"
            destructive: true
            armed: root.pendingAction === label
            onArmRequested: root.pendingAction = label
            onActivated: { Quickshell.execDetached(["systemctl", "poweroff"]); IslandNavigation.close(); }
        }
    }
}
