import QtQuick
import "../../services"
import "../../components"

// Auto-peek card for background activity reported over the "task" IPC
// target (see Tasks.qml) — long-running commands and file transfers show
// up here the same way a DBus notification auto-peeks via NotificationCard.
// Single task: icon + label + progress bar. Multiple: compact list.
Item {
    id: root

    readonly property var list: Tasks.items
    readonly property int count: list.length
    readonly property var single: count === 1 ? list[0] : null

    implicitWidth: Config.notifyWidth
    implicitHeight: col.implicitHeight

    function statusIcon(task) {
        return task.status === "done" ? "check_circle" : task.status === "error" ? "error" : "sync";
    }
    function statusColor(task) {
        return task.status === "done" ? Colors.accent : task.status === "error" ? Colors.danger : Colors.subtext;
    }

    Column {
        id: col
        width: parent.width
        spacing: 10

        // ─── Single task: icon + label + progress bar ────────────────────
        Row {
            width: parent.width
            visible: root.count === 1
            spacing: 12

            MaterialIcon {
                icon: root.single ? root.statusIcon(root.single) : "sync"
                font.pixelSize: 18
                color: root.single ? root.statusColor(root.single) : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: parent.width - 18 - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize
                    text: root.single ? root.single.label : ""
                }

                // Progress bar — indeterminate (progress < 0) just shows an
                // empty track; a real percentage fills it.
                Rectangle {
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Colors.surfaceHigh
                    visible: root.single && root.single.status === "running"

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: Colors.accent
                        width: root.single && root.single.progress >= 0 ? parent.width * Math.max(0, Math.min(1, root.single.progress)) : 0
                        Behavior on width { enabled: !Config.reducedMotion; NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }

        // ─── Multiple tasks: header + compact list ───────────────────────
        Row {
            width: parent.width
            visible: root.count > 1
            spacing: 10

            MaterialIcon {
                icon: "sync"
                font.pixelSize: 18
                color: Colors.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.weight: Font.DemiBold
                text: root.count + " Tasks"
            }
        }

        Column {
            width: parent.width
            visible: root.count > 1
            spacing: 6

            Repeater {
                model: root.list

                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: 6

                    Row {
                        width: parent.width
                        spacing: 8
                        MaterialIcon {
                            icon: root.statusIcon(modelData)
                            font.pixelSize: 14
                            color: root.statusColor(modelData)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            width: parent.width - 22 - percentage.implicitWidth - 8
                            elide: Text.ElideRight
                            font.pixelSize: Config.fontSize - 1
                            text: modelData.label
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            id: percentage
                            text: modelData.status === "running" && modelData.progress >= 0
                                ? Math.round(Math.max(0, Math.min(1, modelData.progress)) * 100) + "%" : ""
                            color: Colors.subtext
                            font.pixelSize: Config.fontSize - 2
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        x: 22
                        width: parent.width - 22
                        height: 4
                        radius: 2
                        color: Colors.surfaceHigh
                        visible: modelData.status === "running"
                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            color: Colors.accent
                            width: modelData.progress >= 0 ? parent.width * Math.max(0, Math.min(1, modelData.progress)) : 0
                            Behavior on width { enabled: !Config.reducedMotion; NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
