import QtQuick
import "../../services"
import "../../components"

// App/screen-time dashboard. Stats and the month heatmap are mock data from
// services/Activity.qml (see that file's header) — the day nav below only
// re-labels the header for now since the mock dataset doesn't vary per day.
Item {
    id: root

    property int dayOffset: 0
    readonly property string dayLabel: dayOffset === 0 ? "Today"
        : Qt.formatDate(new Date(Date.now() + dayOffset * 86400000), "MMM d")

    implicitWidth: 860
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 16

        // --- Header --------------------------------------------------------
        Item {
            width: parent.width
            height: 28

            MaterialIcon {
                icon: "calendar_month"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.centerIn: parent
                spacing: 14

                IconButton { icon: "chevron_left"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.dayOffset -= 1 }
                StyledText {
                    text: root.dayLabel
                    font.bold: true
                    font.pixelSize: Config.fontSize + 2
                    anchors.verticalCenter: parent.verticalCenter
                }
                IconButton { icon: "chevron_right"; anchors.verticalCenter: parent.verticalCenter; onClicked: root.dayOffset += 1 }
            }
        }

        // --- Stat cards ------------------------------------------------------
        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                width: (parent.width - 24) / 3
                height: 78
                radius: Colors.radiusLarge
                color: Colors.surface

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    StyledText { text: "Daily average"; opacity: 0.6; font.pixelSize: Config.fontSize - 2 }
                    StyledText { text: Activity.dailyAverageText; font.bold: true; font.pixelSize: Config.fontSize + 8; font.family: Config.monoFontFamily }
                    StyledText { text: Activity.dailyAverageRange; opacity: 0.5; font.pixelSize: Config.fontSize - 3 }
                }
            }

            Rectangle {
                width: (parent.width - 24) / 3
                height: 78
                radius: Colors.radiusLarge
                color: Colors.surface

                StyledText {
                    anchors.centerIn: parent
                    text: Activity.todayTotalText
                    font.bold: true
                    font.pixelSize: Config.fontSize + 12
                    font.family: Config.monoFontFamily
                }
            }

            Rectangle {
                width: (parent.width - 24) / 3
                height: 78
                radius: Colors.radiusLarge
                color: Colors.surface

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialIcon {
                        icon: Activity.deltaIsDown ? "arrow_downward" : "arrow_upward"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: Activity.deltaText
                        font.bold: true
                        font.pixelSize: Config.fontSize + 8
                        font.family: Config.monoFontFamily
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // --- Weekly chart + month heatmap ------------------------------------
        Row {
            width: parent.width
            spacing: 12

            Rectangle {
                id: chartCard
                width: (parent.width - 12) / 2
                height: 220
                radius: Colors.radiusLarge
                color: Colors.surface

                readonly property real maxMinutes: Math.max(...Activity.weekly.map(d => d.minutes))

                Row {
                    anchors.fill: parent
                    anchors.margins: 18
                    anchors.bottomMargin: 8
                    spacing: 10

                    Repeater {
                        model: Activity.weekly

                        Column {
                            id: dayCol
                            required property var modelData
                            required property int index

                            width: (chartCard.width - 36 - 60) / 7
                            spacing: 6

                            Item {
                                width: dayCol.width
                                height: chartCard.height - 44

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(22, dayCol.width)
                                    height: Math.max(4, (chartCard.height - 44) * (dayCol.modelData.minutes / chartCard.maxMinutes))
                                    radius: 6
                                    color: dayCol.index === Activity.highlightedDayIndex ? Colors.accent : Colors.surfaceHigh
                                }
                            }

                            StyledText {
                                text: dayCol.modelData.day
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: 0.6
                                font.pixelSize: Config.fontSize - 3
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: (parent.width - 12) / 2
                height: 220
                radius: Colors.radiusLarge
                color: Colors.surface

                Column {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    StyledText { text: Activity.monthLabel; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Repeater {
                            model: Activity.monthWeeks

                            Row {
                                required property var modelData
                                spacing: 4

                                Repeater {
                                    model: parent.modelData

                                    Rectangle {
                                        required property int modelData
                                        readonly property bool isToday: modelData === Activity.todayDay
                                        readonly property int level: Activity.levelFor(modelData)

                                        width: 26
                                        height: 26
                                        radius: 6
                                        visible: modelData > 0
                                        color: isToday ? "transparent" : Colors.accent
                                        opacity: isToday ? 1 : (level <= 0 ? 0.12 : 0.3 + level * 0.22)
                                        border.width: isToday ? 2 : 0
                                        border.color: Colors.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- App usage list ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 14

            Repeater {
                model: Activity.apps

                Column {
                    required property var modelData

                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 22

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            MaterialIcon { icon: modelData.icon; anchors.verticalCenter: parent.verticalCenter }
                            StyledText { text: modelData.name; anchors.verticalCenter: parent.verticalCenter }
                        }
                        StyledText {
                            text: modelData.duration
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            font.family: Config.monoFontFamily
                            opacity: 0.8
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Colors.surfaceHigh

                        Rectangle {
                            width: parent.width * modelData.fraction
                            height: parent.height
                            radius: parent.radius
                            color: Colors.accent
                        }
                    }
                }
            }
        }
    }
}
