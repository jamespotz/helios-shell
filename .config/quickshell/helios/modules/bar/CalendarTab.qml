import QtQuick
import "../../services"
import "../../components"

// Real month calendar + agenda, backed by services/Calendar.qml. The
// today/selected/hover cell states below intentionally mirror
// WeatherPanel.qml's forecast mini-grid (same visual language, per
// AGENTS.md's "reuse existing interaction patterns") — the grid math
// itself is a small, deliberate duplication rather than a shared helper,
// since WeatherPanel's version is entangled with forecast-day-selection
// state that has nothing to do with a real calendar.
Item {
    id: root

    property date viewDate: new Date()
    readonly property date today: new Date()
    property date selectedDate: root.today

    function shiftMonth(delta) {
        const d = new Date(root.viewDate);
        d.setDate(1);
        d.setMonth(d.getMonth() + delta);
        root.viewDate = d;
    }

    function dateKey(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    readonly property var weeks: {
        const year = root.viewDate.getFullYear(), month = root.viewDate.getMonth();
        const startOffset = new Date(year, month, 1).getDay();
        const daysInMonth = new Date(year, month + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < startOffset; i++) cells.push(0);
        for (let d = 1; d <= daysInMonth; d++) cells.push(d);
        while (cells.length % 7 !== 0) cells.push(0);
        const rows = [];
        for (let i = 0; i < cells.length; i += 7) rows.push(cells.slice(i, i + 7));
        return rows;
    }

    readonly property bool viewingCurrentMonth: root.viewDate.getFullYear() === root.today.getFullYear()
        && root.viewDate.getMonth() === root.today.getMonth()

    readonly property var eventsByDate: Calendar.eventsByDate(Calendar.events)
    readonly property var selectedDayEvents: root.eventsByDate[root.dateKey(root.selectedDate)] || []

    Component.onCompleted: Calendar.open()
    Component.onDestruction: Calendar.close()

    implicitWidth: 340
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // --- Month header ------------------------------------------------------
        Item {
            width: parent.width
            height: 28

            IconButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_left"
                onClicked: root.shiftMonth(-1)
            }
            StyledText {
                anchors.centerIn: parent
                font.bold: true
                text: root.viewDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
                onClicked: root.shiftMonth(1)
            }
        }

        // --- Weekday labels ------------------------------------------------
        Row {
            width: parent.width
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                StyledText {
                    required property string modelData
                    width: col.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    opacity: 0.5
                    font.pixelSize: Config.fontSize - 3
                }
            }
        }

        // --- Day grid --------------------------------------------------------
        Column {
            width: parent.width
            spacing: 1

            Repeater {
                model: root.weeks

                Row {
                    required property var modelData
                    width: col.width

                    Repeater {
                        model: parent.modelData

                        Item {
                            id: cell
                            required property int modelData
                            readonly property date cellDate: new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData || 1)
                            readonly property string cellKey: root.dateKey(cell.cellDate)
                            readonly property bool isToday: root.viewingCurrentMonth && modelData === root.today.getDate()
                            readonly property bool isSelected: modelData > 0
                                && cell.cellDate.getFullYear() === root.selectedDate.getFullYear()
                                && cell.cellDate.getMonth() === root.selectedDate.getMonth()
                                && cell.cellDate.getDate() === root.selectedDate.getDate()
                            readonly property bool hasEvents: modelData > 0 && !!root.eventsByDate[cell.cellKey]

                            width: col.width / 7
                            height: width
                            visible: modelData > 0

                            // Today: solid accent circle
                            Rectangle {
                                visible: cell.isToday
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 4
                                height: width
                                radius: width / 2
                                color: Colors.accent
                            }

                            // Selected day: outline ring
                            Rectangle {
                                visible: !cell.isToday && cell.isSelected
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 3
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Colors.accent
                            }

                            // Hover state
                            Rectangle {
                                visible: !cell.isToday && dayHover.hovered
                                anchors.centerIn: parent
                                width: Math.min(parent.width, parent.height) - 4
                                height: width
                                radius: width / 2
                                color: Colors.overlay
                                opacity: 0.2
                            }

                            HoverHandler { id: dayHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedDate = cell.cellDate
                            }

                            StyledText {
                                anchors.centerIn: parent
                                text: cell.modelData
                                font.pixelSize: Config.fontSize - 6
                                font.weight: cell.isToday ? Font.Bold : Font.Normal
                                color: cell.isToday ? Colors.accentText : Colors.text
                            }

                            // Event indicator dot
                            Rectangle {
                                visible: cell.hasEvents
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: 4; height: 4; radius: 2
                                color: cell.isToday ? Colors.accentText : Colors.accent
                            }
                        }
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }

        // --- Agenda for selected day -----------------------------------------
        Column {
            width: parent.width
            spacing: 8

            StyledText {
                font.bold: true
                text: root.selectedDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
            }

            StyledText {
                visible: root.selectedDayEvents.length === 0
                text: "No events"
                opacity: 0.5
                font.pixelSize: Config.fontSize - 2
            }

            Column {
                width: parent.width
                spacing: 6
                visible: root.selectedDayEvents.length > 0

                Repeater {
                    model: root.selectedDayEvents

                    Row {
                        required property var modelData
                        width: parent.width
                        spacing: 10

                        StyledText {
                            width: 60
                            text: modelData.allDay ? "All day" : (modelData.startTime || "")
                            opacity: 0.6
                            font.pixelSize: Config.fontSize - 3
                            font.family: Config.monoFontFamily
                        }
                        StyledText {
                            width: parent.width - 70
                            elide: Text.ElideRight
                            text: modelData.summary
                        }
                    }
                }
            }
        }
    }
}
