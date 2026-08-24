import QtQuick
import Quickshell
import "../../services"
import "../../components"

Item {
    id: root

    readonly property var list: Notifications.list
    readonly property int count: list.length

    // Hovering pauses the auto-dismiss timer in Bar.qml (only relevant for
    // the single-notification view — a group stays until cleared).
    readonly property bool hovering: hoverTracker.hovered

    implicitWidth: Config.notifyWidth
    implicitHeight: col.implicitHeight

    HoverHandler { id: hoverTracker }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Row {
            width: parent.width
            visible: root.count === 1
            spacing: 10

            Image {
                width: 40
                height: 40
                anchors.verticalCenter: parent.verticalCenter
                visible: root.count === 1 && source !== ""
                source: root.count === 1 ? (root.list[0].image || Quickshell.iconPath(root.list[0].appIcon, true)) : ""
                fillMode: Image.PreserveAspectFit
            }

            Column {
                width: parent.width - 40 - 10 - 28 - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    font.bold: true
                    text: root.count === 1 ? root.list[0].summary : ""
                }
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    opacity: 0.75
                    font.pixelSize: Config.fontSize - 1
                    text: root.count === 1 ? root.list[0].body : ""
                }
            }

            IconButton {
                icon: "close"
                iconSize: 14
                anchors.verticalCenter: parent.verticalCenter
                onClicked: if (root.count === 1) Notifications.dismiss(root.list[0])
            }
        }

        Row {
            width: parent.width
            visible: root.count > 1
            spacing: 10

            MaterialIcon {
                icon: "notifications"
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 22 - 70 - 20
                font.bold: true
                text: root.count + " notifications"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Clear all"
                color: Colors.accent

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.dismissAll()
                }
            }
        }

        ListView {
            id: groupList
            width: parent.width - 8
            visible: root.count > 1
            height: visible ? Math.min(220, Math.max(0, root.count * 44)) : 0
            clip: true
            spacing: 2
            model: root.list
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: groupList }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                width: groupList.width
                height: 40
                radius: Colors.radiusSmall
                color: mouse.containsMouse ? Colors.surface : "transparent"
                Behavior on color { ColorAnimation { duration: Config.animFast } }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Image {
                        width: 22
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        visible: source !== ""
                        source: row.modelData.image || Quickshell.iconPath(row.modelData.appIcon, true)
                        fillMode: Image.PreserveAspectFit
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: row.width - 22 - 16 - 22 - 24
                        elide: Text.ElideRight
                        text: row.modelData.summary
                    }

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        font.pixelSize: 14

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.dismiss(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
