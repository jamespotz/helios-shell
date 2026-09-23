import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../../components"
import "../../services"

MaterialIcon {
    id: root

    required property var targetScreen
    property bool active: false
    readonly property var monitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null
    readonly property int activeWorkspaceId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
    property string layout: ""
    readonly property TiledLayoutCore core: TiledLayoutCore {}

    visible: active && layout.length > 0
    icon: core.iconForLayout(layout)
    color: Colors.accent
    font.pixelSize: 14

    function refresh() {
        if (!root.active || root.activeWorkspaceId === 0 || query.running)
            return;
        query.running = true;
    }

    onActiveWorkspaceIdChanged: refresh()
    onActiveChanged: refresh()
    Component.onCompleted: refresh()

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: query
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.layout = root.core.layoutForWorkspace(text, root.activeWorkspaceId)
        }
    }
}
