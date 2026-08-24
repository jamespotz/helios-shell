import QtQuick
import Quickshell.Hyprland
import "../../services"

// Apple-style workspace indicators — rounded pill for active workspace,
// small dots for others. Clean, minimal, with smooth transitions.
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
            width: modelData.focused ? 22 : 7
            height: 7
            radius: height / 2
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            color: modelData.focused ? Colors.accent
                : modelData.urgent ? Colors.danger
                : Colors.overlay

            opacity: modelData.focused ? 1 : 0.6

            Behavior on width { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: Config.animFast } }
            Behavior on opacity { NumberAnimation { duration: Config.animFast } }

            // Hover ring — subtle outline on non-focused dots
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: Colors.text
                opacity: dotHover.hovered && !dot.modelData.focused ? 0.3 : 0
                Behavior on opacity { NumberAnimation { duration: Config.animFast } }
            }

            HoverHandler { id: dotHover }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + dot.modelData.id + " })")
            }
        }
    }
}
