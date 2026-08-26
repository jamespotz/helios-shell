import QtQuick
import "../../services"
import "../../components"

// Notification history panel — scrollable list of past notifications
// (persisted even after dismiss). Shows app name, summary, time.
Item {
    id: root

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 12

        // Header with clear button
        Row {
            width: parent.width

            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                MaterialIcon { icon: "history"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "Notification History"; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }

            Item { width: parent.width - parent.children[0].width - clearBtn.width; height: 1 }

            Rectangle {
                id: clearBtn
                visible: Notifications.history.length > 0
                width: clearText.implicitWidth + 16
                height: 26
                radius: 13
                color: clearBtnHover.hovered ? Colors.surfaceHigh : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear"
                    font.pixelSize: Config.fontSize - 1
                    font.weight: Font.Medium
                    color: Colors.accent
                }

                HoverHandler { id: clearBtnHover }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notifications.clearHistory() }
            }
        }

        // DND status banner
        Rectangle {
            visible: Bridge.dndEnabled
            width: parent.width
            height: 32
            radius: 10
            color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.12)

            Row {
                anchors.centerIn: parent
                spacing: 6
                MaterialIcon { icon: "do_not_disturb_on"; font.pixelSize: 14; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: "Do Not Disturb is on"; font.pixelSize: Config.fontSize - 1; color: Colors.warning; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Empty state
        Column {
            visible: Notifications.history.length === 0
            width: parent.width
            spacing: 8
            topPadding: 20

            MaterialIcon { icon: "notifications_none"; font.pixelSize: 32; color: Colors.overlay; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText { text: "No notifications yet"; color: Colors.subtext; anchors.horizontalCenter: parent.horizontalCenter }
        }

        // History list
        ListView {
            id: historyList
            width: parent.width
            visible: Notifications.history.length > 0
            height: Math.min(320, Notifications.history.length * 68)
            clip: true
            spacing: 4
            model: Notifications.history
            boundsBehavior: Flickable.StopAtBounds

            ScrollIndicator { target: historyList }

            delegate: Rectangle {
                id: histRow
                required property var modelData
                required property int index

                width: historyList.width
                height: 64
                radius: 10
                color: histHover.hovered ? Colors.surfaceHigh : "transparent"

                // Truncate to a fixed character budget rather than relying on
                // single-line width-elide, which cropped long bodies after
                // only a handful of characters.
                function truncate(text, max) {
                    return text.length > max ? text.slice(0, max).replace(/\s+$/, "") + "…" : text;
                }

                HoverHandler { id: histHover }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 10

                    // App icon placeholder
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        color: Colors.surfaceHigh
                        anchors.verticalCenter: parent.verticalCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            icon: "notifications"
                            font.pixelSize: 16
                            color: Colors.subtext
                        }
                    }

                    // Content
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: histRow.width - 16 - 32 - 28 - 60 - 40
                        spacing: 2

                        StyledText {
                            width: parent.width
                            elide: Text.ElideRight
                            font.weight: Font.Medium
                            font.pixelSize: Config.fontSize - 1
                            text: histRow.modelData.summary || ""
                        }

                        StyledText {
                            visible: (histRow.modelData.body || "").length > 0
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            font.pixelSize: Config.fontSize - 2
                            color: Colors.subtext
                            text: histRow.truncate(histRow.modelData.body || "", 150)
                        }
                    }

                    // Open app — uses the smart priority chain:
                    // focus window → default action/deep link → launch app
                    MouseArea {
                        id: openBtn
                        width: 28
                        height: 28
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: Notifications.openNotification(histRow.modelData)

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: openBtn.containsMouse ? Colors.surfaceHigh : "transparent"

                            MaterialIcon {
                                anchors.centerIn: parent
                                icon: "open_in_new"
                                font.pixelSize: 14
                                color: Colors.accent
                            }
                        }
                    }

                    // Time
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 60
                        horizontalAlignment: Text.AlignRight
                        font.pixelSize: Config.fontSize - 3
                        color: Colors.subtext
                        text: {
                            if (!histRow.modelData.time) return "";
                            const t = histRow.modelData.time;
                            const now = new Date();
                            const diffMs = now - t;
                            const diffMin = Math.floor(diffMs / 60000);
                            if (diffMin < 1) return "now";
                            if (diffMin < 60) return diffMin + "m";
                            const diffH = Math.floor(diffMin / 60);
                            if (diffH < 24) return diffH + "h";
                            return Qt.formatDate(t, "MMM d");
                        }
                    }
                }
            }
        }

        // Count footer
        StyledText {
            visible: Notifications.history.length > 0
            text: Notifications.history.length + " notification" + (Notifications.history.length !== 1 ? "s" : "") + " in history"
            font.pixelSize: Config.fontSize - 2
            color: Colors.subtext
        }
    }
}
