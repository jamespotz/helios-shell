import QtQuick
import "../../services"
import "../../components"

// App/screen-time dashboard, backed by real focus-time tracking in
// services/Activity.qml (see that file's header — now idle-aware via
// Quickshell's native ext-idle-notify-v1 binding). The day nav pages the
// hero total + app list through Activity's date-parameterized helpers; the
// weekly chart and month heatmap intentionally stay pinned to "this week" /
// "this month" regardless of the selected day, same as Apple's Screen Time —
// only the selected day's bar/cell gets the highlight.
Item {
    id: root

    property int dayOffset: 0

    readonly property date selectedDate: {
        const d = new Date();
        d.setHours(0, 0, 0, 0);
        d.setDate(d.getDate() + root.dayOffset);
        return d;
    }
    readonly property string selectedDayKey: Activity.dayKeyFor(root.selectedDate)
    readonly property string dayLabel: dayOffset === 0 ? "Today" : Qt.formatDate(root.selectedDate, "MMM d")

    readonly property real selectedTotalSeconds: Activity.totalSecondsFor(root.selectedDayKey)
    readonly property string selectedTotalText: Activity.fmtDuration(root.selectedTotalSeconds)
    readonly property var selectedApps: Activity.appsFor(root.selectedDayKey)

    readonly property bool selectedIsDown: root.selectedTotalSeconds < Activity.dailyAverageSeconds
    readonly property string selectedDeltaText: Activity.fmtDuration(Math.abs(root.selectedTotalSeconds - Activity.dailyAverageSeconds))

    // Which weekly-chart bar (if any) corresponds to the selected day —
    // -1 once the nav pages outside the current week, so nothing lights up.
    readonly property int chartHighlightIndex: {
        const diffDays = Math.round((root.selectedDate.getTime() - Activity.weekDates[0].getTime()) / 86400000);
        return (diffDays >= 0 && diffDays < 7) ? diffDays : -1;
    }

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
                opacity: 0.7
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
                IconButton {
                    icon: "chevron_right"
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.dayOffset < 0
                    opacity: enabled ? 1 : 0.3
                    onClicked: root.dayOffset += 1
                }
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
                color: Colors.surfaceHigh

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

            // Hero card — the selected day's total is the number this whole
            // screen exists to answer, so it gets an accent ring and the
            // biggest type instead of being just a third equal box.
            Rectangle {
                width: (parent.width - 24) / 3
                height: 78
                radius: Colors.radiusLarge
                color: Colors.surfaceHigh
                border.width: 1.5
                border.color: Colors.accent

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    StyledText {
                        text: root.dayLabel.toUpperCase()
                        opacity: 0.6
                        font.pixelSize: Config.fontSize - 2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    StyledText {
                        text: root.selectedTotalText
                        color: Colors.accent
                        font.bold: true
                        font.pixelSize: Config.fontSize + 12
                        font.family: Config.monoFontFamily
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Rectangle {
                width: (parent.width - 24) / 3
                height: 78
                radius: Colors.radiusLarge
                color: Colors.surfaceHigh

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    StyledText { text: "vs. average"; opacity: 0.6; font.pixelSize: Config.fontSize - 2; anchors.horizontalCenter: parent.horizontalCenter }

                    Row {
                        spacing: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        MaterialIcon {
                            icon: root.selectedIsDown ? "arrow_downward" : "arrow_upward"
                            color: root.selectedIsDown ? Colors.success : Colors.danger
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.selectedDeltaText
                            font.bold: true
                            font.pixelSize: Config.fontSize + 8
                            font.family: Config.monoFontFamily
                            anchors.verticalCenter: parent.verticalCenter
                        }
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
                color: Colors.surfaceHigh

                readonly property real maxMinutes: Math.max(1, ...Activity.weekly.map(d => d.minutes))

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
                            readonly property bool isSelected: index === root.chartHighlightIndex

                            width: (chartCard.width - 36 - 60) / 7
                            spacing: 6

                            Item {
                                width: dayCol.width
                                height: chartCard.height - 44

                                Rectangle {
                                    id: bar
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(22, dayCol.width)
                                    height: Math.max(4, (chartCard.height - 44) * (dayCol.modelData.minutes / chartCard.maxMinutes))
                                    radius: 6
                                    color: dayCol.isSelected ? Colors.accent : Colors.surface

                                    // Soft halo behind the selected day — the
                                    // same "today" glow language used on the
                                    // calendar and the workspace dots.
                                    Rectangle {
                                        visible: dayCol.isSelected
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        width: parent.width + 10
                                        height: parent.height + 6
                                        radius: 8
                                        color: Colors.accent
                                        opacity: 0.2
                                        z: -1
                                    }
                                }
                            }

                            StyledText {
                                text: dayCol.modelData.day
                                anchors.horizontalCenter: parent.horizontalCenter
                                opacity: dayCol.isSelected ? 1 : 0.6
                                font.bold: dayCol.isSelected
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
                color: Colors.surfaceHigh

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

                                    Item {
                                        required property int modelData
                                        readonly property bool isToday: modelData === Activity.todayDay
                                        readonly property int level: Activity.levelFor(modelData)

                                        width: 26
                                        height: 26
                                        visible: modelData > 0

                                        Rectangle {
                                            visible: parent.isToday
                                            anchors.centerIn: parent
                                            width: parent.width + 6
                                            height: parent.height + 6
                                            radius: 9
                                            color: Colors.accent
                                            opacity: 0.2
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 6
                                            color: parent.isToday ? "transparent" : Colors.accent
                                            opacity: parent.isToday ? 1 : (parent.level <= 0 ? 0.12 : 0.3 + parent.level * 0.22)
                                            border.width: parent.isToday ? 1.5 : 0
                                            border.color: Colors.accent
                                        }
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

            StyledText {
                visible: root.selectedApps.length === 0
                text: "No activity tracked for this day"
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
            }

            Repeater {
                model: root.selectedApps

                Column {
                    required property var modelData

                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 30

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: Colors.radiusSmall
                                color: Colors.surfaceHigh
                                anchors.verticalCenter: parent.verticalCenter

                                MaterialIcon { anchors.centerIn: parent; icon: modelData.icon; font.pixelSize: 15 }
                            }

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
                        height: 5
                        radius: height / 2
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
