import QtQuick
import "../../services"
import "../../components"

// GitHub inbox — unread notifications from GitHub.qml, newest first.
// Opening a thread or marking it read updates GitHub too.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    function timeAgo(t) {
        const diffMin = Math.floor((Date.now() - t) / 60000);
        if (diffMin < 1) return "now";
        if (diffMin < 60) return diffMin + "m";
        const diffH = Math.floor(diffMin / 60);
        if (diffH < 24) return diffH + "h";
        return Qt.formatDate(t, "MMM d");
    }

    Column {
        id: col
        width: parent.width
        spacing: 12

        Row {
            width: parent.width

            Row {
                id: title
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                GitHubMark { size: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "GitHub"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }

            Item { width: Math.max(0, parent.width - title.width - actions.width); height: 1 }

            Row {
                id: actions
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    icon: "refresh"
                    label: "Check now"
                    enabled: !GitHub.checking
                    onClicked: GitHub.refresh()
                }
                IconButton {
                    icon: "done_all"
                    label: "Mark all as read"
                    enabled: GitHub.items.length > 0
                    onClicked: GitHub.markAllRead()
                }
            }
        }

        // Error banner, same treatment as Notification History's DND banner.
        Rectangle {
            visible: GitHub.error !== ""
            width: parent.width
            height: 32
            radius: 10
            color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.12)

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialIcon { icon: "error"; font.pixelSize: 14; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: GitHub.error; font.pixelSize: Config.fontSize - 1; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        Column {
            visible: GitHub.items.length === 0 && GitHub.error === ""
            width: parent.width
            spacing: 8
            topPadding: 20
            bottomPadding: 12

            MaterialIcon { icon: "done_all"; font.pixelSize: 32; color: Colors.overlay; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText { text: "You're all caught up"; color: Colors.subtext; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // Wrapped so ScrollIndicator is a sibling of the Flickable (see
        // components/ScrollIndicator.qml).
        Item {
            width: parent.width
            visible: GitHub.items.length > 0
            height: Math.min(320, GitHub.items.length * 56)

            ListView {
                id: inboxList
                anchors.fill: parent
                clip: true
                spacing: 4
                model: GitHub.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: row
                    signal clicked()
                    onClicked: { AlertSounds.play("tap"); GitHub.open(row.modelData.id); }
                    activeFocusOnTab: true
                    Keys.onReturnPressed: clicked()
                    Keys.onSpacePressed: clicked()
                    Accessible.role: Accessible.Button
                    Accessible.name: row.modelData.title
                    Accessible.onPressAction: clicked()
                    required property var modelData

                    width: inboxList.width
                    height: 52
                    radius: 10
                    color: rowHover.hovered ? Colors.surfaceHigh : "transparent"

                    HoverHandler { id: rowHover }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 8
                        color: "transparent"
                        border.width: 2
                        border.color: Colors.accent
                        visible: row.activeFocus
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.clicked()
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 10

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: Colors.surfaceHigh
                            anchors.verticalCenter: parent.verticalCenter

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: row.modelData.icon
                                font.pixelSize: 16
                                color: Colors.subtext
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: row.width - 16 - 32 - timeText.width - readButton.width - 30
                            spacing: 2

                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                font.weight: Font.Medium
                                font.pixelSize: Config.fontSize - 1
                                text: row.modelData.title
                            }
                            StyledText {
                                width: parent.width
                                elide: Text.ElideRight
                                font.pixelSize: Config.fontSize - 2
                                color: Colors.subtext
                                text: row.modelData.reasonLabel + " · " + row.modelData.repo
                            }
                        }

                        StyledText {
                            id: timeText
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: Config.fontSize - 3
                            color: Colors.subtext
                            text: root.timeAgo(row.modelData.time)
                        }

                        IconButton {
                            id: readButton
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "check"
                            iconSize: 14
                            label: "Mark as read"
                            onClicked: GitHub.markRead(row.modelData.id)
                        }
                    }
                }
            }

            ScrollIndicator { target: inboxList }
        }

        StyledText {
            visible: GitHub.items.length > 0
            text: GitHub.items.length + " unread"
            font.pixelSize: Config.fontSize - 2
            color: Colors.subtext
        }
    }
}
