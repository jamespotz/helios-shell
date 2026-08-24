import QtQuick
import Quickshell.Hyprland
import "../../services"

Row {
    id: root

    required property var targetScreen
    readonly property var monitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null

    spacing: 6

    Repeater {
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: dot
            required property var modelData

            visible: root.monitor === null || modelData.monitor === root.monitor
            width: modelData.focused ? 20 : 8
            height: 8
            radius: 4
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            color: modelData.focused ? Colors.accent
                : modelData.urgent ? Colors.danger
                : Colors.overlay

            Behavior on width { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Config.animFast } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Colors.text
                opacity: dotHover.hovered ? 0.4 : 0
            }

            HoverHandler { id: dotHover }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // This fork's Hyprland requires dispatches as Lua calls
                // (hl.dsp.<name>(...)), not plain "workspace <id>" strings —
                // the latter fails to parse over the IPC socket.
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })")
            }
        }
    }
}
