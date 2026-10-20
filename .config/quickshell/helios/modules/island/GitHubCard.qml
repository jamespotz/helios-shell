import QtQuick
import "../../services"
import "../../components"

// Alert card for new GitHub notifications — GitHub.qml's popups, newest
// first. Clicking a thread opens it in the browser and marks it read; the
// close button only marks it read. The pause hides the card but leaves the
// threads unread in the GitHub destination.
Item {
    id: root

    readonly property var list: GitHub.popups

    implicitWidth: Config.notifyWidth
    implicitHeight: col.implicitHeight

    HoverHandler { id: hoverTracker }

    // Each new thread restarts the pause; hovering holds the card open.
    Timer {
        id: autoDismissTimer
        interval: Config.notifyDuration
        onTriggered: {
            if (hoverTracker.hovered) { autoDismissTimer.restart(); return; }
            GitHub.hideAllPopups();
        }
    }
    onListChanged: if (root.list.length > 0) autoDismissTimer.restart()
    Component.onCompleted: autoDismissTimer.restart()

    Column {
        id: col
        width: parent.width
        spacing: 4

        Repeater {
            model: root.list.slice(0, 4)

            delegate: Rectangle {
                id: row
                required property var modelData

                width: col.width
                height: 44
                radius: Colors.radiusSmall
                color: rowHover.hovered && root.list.length > 1 ? Colors.surfaceHigh : "transparent"

                Behavior on color { ColorAnimation { duration: Config.animFast } }

                HoverHandler { id: rowHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { AlertSounds.play("tap"); GitHub.open(row.modelData.id); }
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: root.list.length > 1 ? 8 : 0
                    anchors.rightMargin: root.list.length > 1 ? 8 : 0
                    spacing: 12

                    MaterialIcon {
                        icon: row.modelData.icon
                        font.pixelSize: 20
                        color: Colors.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: parent.width - 20 - 12 - closeButton.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.weight: Font.DemiBold
                            text: row.modelData.title
                        }
                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            color: Colors.subtext
                            font.pixelSize: Config.fontSize - 2
                            text: row.modelData.reasonLabel + " · " + row.modelData.repo
                        }
                    }

                    IconButton {
                        id: closeButton
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        iconSize: 14
                        label: "Mark as read"
                        onClicked: GitHub.markRead(row.modelData.id)
                    }
                }
            }
        }

        StyledText {
            visible: root.list.length > 4
            leftPadding: 8
            text: "+" + (root.list.length - 4) + " more in GitHub"
            font.pixelSize: Config.fontSize - 2
            color: Colors.subtext
        }
    }
}
