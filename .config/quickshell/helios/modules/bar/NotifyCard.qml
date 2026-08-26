import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Apple-style notification banner — clean card layout with app icon,
// title/body hierarchy, and subtle action buttons. Single notifications
// show full detail; multiple collapse into a compact scrollable list
// with a "Clear All" action.
Item {
    id: root

    readonly property var list: Notifications.list
    readonly property int count: list.length

    readonly property bool hovering: hoverTracker.hovered

    implicitWidth: Config.notifyWidth
    implicitHeight: col.implicitHeight

    HoverHandler { id: hoverTracker }

    Column {
        id: col
        width: parent.width
        spacing: 12

        // ─── Single notification: full detail ────────────────────────────
        Row {
            width: parent.width
            visible: root.count === 1
            spacing: 12

            // App icon — rounded square (Apple notification style)
            Rectangle {
                width: 36
                height: 36
                radius: 8
                color: Colors.surfaceHigh
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: root.count === 1 && source !== ""
                    source: root.count === 1 ? (root.list[0].image || Quickshell.iconPath(root.list[0].appIcon, true)) : ""
                    fillMode: Image.PreserveAspectFit
                }
            }

            // Title + body
            Column {
                width: parent.width - 36 - 12 - actionRow.width - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize
                    text: root.count === 1 ? root.list[0].summary : ""
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    color: Colors.subtext
                    font.pixelSize: Config.fontSize - 1
                    text: root.count === 1 ? root.list[0].body : ""
                }
            }

            // Action buttons
            Row {
                id: actionRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                IconButton {
                    icon: "open_in_new"
                    iconSize: 14
                    visible: root.count === 1 && Notifications.hasDefaultAction(root.list[0])
                    onClicked: if (root.count === 1) Notifications.focusApp(root.list[0])
                }

                IconButton {
                    icon: "close"
                    iconSize: 14
                    onClicked: if (root.count === 1) Notifications.dismiss(root.list[0])
                }
            }
        }

        // ─── Multiple notifications: header + list ───────────────────────
        Row {
            width: parent.width
            visible: root.count > 1
            spacing: 10

            MaterialIcon {
                icon: "notifications"
                font.pixelSize: 18
                color: Colors.accent
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 18 - 10 - clearAll.width - 10
                font.weight: Font.DemiBold
                text: root.count + " Notifications"
            }

            // Clear all — pill-shaped text button (Apple style)
            Rectangle {
                id: clearAll
                anchors.verticalCenter: parent.verticalCenter
                width: clearText.implicitWidth + 16
                height: 24
                radius: 12
                color: clearHover.containsMouse ? Colors.surfaceHigh : "transparent"

                Behavior on color { ColorAnimation { duration: Config.animFast } }

                StyledText {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.pixelSize: Config.fontSize - 1
                    font.weight: Font.Medium
                    color: Colors.accent
                }

                MouseArea {
                    id: clearHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismissAll()
                }
            }
        }

        // Notification list
        ListView {
            id: groupList
            width: parent.width
            visible: root.count > 1
            height: visible ? Math.min(220, Math.max(0, root.count * 48)) : 0
            clip: true
            spacing: 4
            model: root.list
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: groupList }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: groupList.width
                height: 44
                radius: Colors.radiusSmall
                color: mouse.containsMouse ? Colors.surfaceHigh : "transparent"
                opacity: mouse.containsMouse ? 0.6 : 1

                Behavior on color { ColorAnimation { duration: Config.animFast } }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    // App icon — small rounded square
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        color: Colors.surfaceHigh
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: source !== ""
                            source: row.modelData.image || Quickshell.iconPath(row.modelData.appIcon, true)
                            fillMode: Image.PreserveAspectFit
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.width - 24 - 10 - 16 - 28 - 28 - 30
                        elide: Text.ElideRight
                        font.pixelSize: Config.fontSize - 1
                        text: row.modelData.summary
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "open_in_new"
                        iconSize: 13
                        visible: Notifications.hasDefaultAction(row.modelData)
                        onClicked: Notifications.focusApp(row.modelData)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        iconSize: 13
                        onClicked: Notifications.dismiss(row.modelData)
                    }
                }
            }
        }
    }
}
