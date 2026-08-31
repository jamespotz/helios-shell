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
    property bool manageOpen: false

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
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    icon: "tune"
                    active: root.manageOpen
                    onClicked: root.manageOpen = !root.manageOpen
                }
                IconButton {
                    icon: "chevron_right"
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        // --- Manage calendars (subscriptions) --------------------------------
        Column {
            width: parent.width
            spacing: 10
            visible: root.manageOpen
            height: root.manageOpen ? implicitHeight : 0
            clip: true

            StyledText { text: "Calendars"; font.bold: true; font.pixelSize: Config.fontSize - 1 }

            StyledText {
                visible: Calendar.subscriptions.length === 0
                text: "No subscribed calendars yet"
                opacity: 0.5
                font.pixelSize: Config.fontSize - 2
            }

            Column {
                width: parent.width
                spacing: 4
                visible: Calendar.subscriptions.length > 0

                Repeater {
                    model: Calendar.subscriptions

                    Item {
                        id: subRow
                        required property var modelData
                        readonly property var error: Calendar.subscriptionErrors.find(e => e.id === subRow.modelData.id) || null

                        width: parent.width
                        height: 32

                        Row {
                            anchors.fill: parent
                            spacing: 8

                            MaterialIcon {
                                visible: !!subRow.error
                                icon: "warning"
                                font.pixelSize: 14
                                color: Colors.warning
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                width: parent.width - (subRow.error ? 18 : 0) - 32
                                anchors.verticalCenter: parent.verticalCenter
                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: subRow.modelData.label
                                }
                                StyledText {
                                    visible: !!subRow.error
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: subRow.error ? subRow.error.message : ""
                                    color: Colors.warning
                                    font.pixelSize: Config.fontSize - 4
                                }
                            }
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "close"
                                iconSize: 14
                                onClicked: Calendar.removeSubscription(subRow.modelData.id)
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }

            Column {
                width: parent.width
                spacing: 8

                SearchField {
                    id: labelField
                    width: parent.width
                    icon: "label"
                    placeholder: "Name (e.g. Work)"
                }
                SearchField {
                    id: urlField
                    width: parent.width
                    icon: "link"
                    placeholder: "https://calendar.google.com/…/basic.ics"
                    onAccepted: addButton.clicked()
                }
                PrimaryButton {
                    id: addButton
                    width: parent.width
                    text: "Add Calendar"
                    icon: "add"
                    enabled: labelField.text.trim().length > 0 && urlField.text.trim().length > 0
                    onClicked: {
                        Calendar.addSubscription(labelField.text, urlField.text);
                        labelField.text = "";
                        urlField.text = "";
                    }
                }
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
                            // Leading/trailing blank cells (modelData === 0)
                            // must still occupy their column so day 1 lands
                            // under the correct weekday — hiding them with
                            // `visible` collapses them out of the Row
                            // positioner and shifts the whole month left.
                            opacity: modelData > 0 ? 1 : 0
                            enabled: modelData > 0

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
