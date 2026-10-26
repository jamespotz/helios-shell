pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Ending or pausing the session, shared by the power menu and the lock screen.
QtObject {
    // This machine's Hyprland runs a lua-config plugin that wraps every
    // `dispatch` payload as `hl.dispatch(<payload>)` and evaluates it as Lua,
    // so a bare dispatcher name like "exit" fails silently. binds.lua uses
    // the same working form: hl.dsp.exit().
    function logout() { Hyprland.dispatch("hl.dsp.exit()") }
    function suspend() { Quickshell.execDetached(["systemctl", "suspend"]) }
    function reboot() { Quickshell.execDetached(["systemctl", "reboot"]) }
    function poweroff() { Quickshell.execDetached(["systemctl", "poweroff"]) }
}
