pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Game mode — strips Hyprland's eye candy (animations, blur, shadows, gaps,
// rounding, inactive opacity). ShellState.dndEnabled and IdleInhibit.inhibited
// read `enabled`, so DND and caffeine hold for as long as it's on.
// Turning it off reloads the Hyprland config. Feral gamemoded is left to per-game `gamemoderun`:
// held shell-wide, its performance governor keeps the CPU at boost clocks.
QtObject {
    id: root

    // Aliased to the adapter so the persisted value survives the async load
    // (see the comment in NightLight.qml).
    property alias enabled: adapter.enabled

    readonly property string _perfConfig: "hl.config({"
        + " animations = { enabled = false },"
        + " decoration = { rounding = 0, active_opacity = 1, inactive_opacity = 1,"
        + " shadow = { enabled = false }, blur = { enabled = false } },"
        + " general = { gaps_in = 0, gaps_out = 0 } })"

    function toggle() { root.setEnabled(!root.enabled) }

    function setEnabled(v) {
        if (root.enabled === v) return;
        root.enabled = v;
        if (v) root._applyHyprland();
        else Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function _applyHyprland() {
        Quickshell.execDetached(["hyprctl", "eval", root._perfConfig]);
    }

    // Other services run `hyprctl reload` (theme export, displays), which
    // would restore the eye candy mid-game.
    property Connections hyprlandWatcher: Connections {
        target: Hyprland
        enabled: root.enabled
        function onRawEvent(event) {
            if (event.name === "configreloaded") root._applyHyprland();
        }
    }

    property FileView settingsFile: FileView {
        path: Quickshell.statePath("gamemode.json")
        watchChanges: false
        onAdapterUpdated: root.saveTimer.restart()

        JsonAdapter {
            id: adapter
            property bool enabled: false
        }

        onLoaded: if (root.enabled) root._applyHyprland()
    }

    property Timer saveTimer: Timer {
        interval: 300
        onTriggered: root.settingsFile.writeAdapter()
    }
}
