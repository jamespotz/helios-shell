import QtQuick
import "../../services"
import "../../components"

// Merged calendar + live clock + weather panel — replaces the old separate
// WeatherInfo (weather tab) and Calendar (opened from Clock.qml) panels.
// Current temp/condition/humidity/wind/feels-like and the hourly strip come
// from the real Weather service; the day-nav on the right indexes into
// Weather.daily (today + the next two days — wttr.in's free-tier limit) so
// it actually shows that day's forecast, not just a relabeled today.
Item {
    id: root

    // --- Calendar month grid (same algorithm as the old Calendar.qml) --------
    property date viewDate: new Date()
    readonly property date today: new Date()

    function shiftMonth(delta) {
        const d = new Date(root.viewDate);
        d.setDate(1);
        d.setMonth(d.getMonth() + delta);
        root.viewDate = d;
    }

    readonly property var weeks: {
        const year = viewDate.getFullYear(), month = viewDate.getMonth();
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

    readonly property bool viewingCurrentMonth: viewDate.getFullYear() === today.getFullYear()
        && viewDate.getMonth() === today.getMonth()

    // --- Day nav on the right — indexes Weather.daily, clamped to what's
    // actually available (0 = today, up to Weather.daily.length - 1) --------
    property int dayOffset: 0
    readonly property int maxDayOffset: Math.max(0, Weather.daily.length - 1)
    onMaxDayOffsetChanged: dayOffset = Math.min(dayOffset, maxDayOffset)
    readonly property var selectedDay: Weather.daily.length > dayOffset ? Weather.daily[dayOffset] : null
    readonly property date selectedDate: {
        // Parse "yyyy-MM-dd" as a local date, not UTC — new Date(string) would
        // parse it as UTC midnight and can land on the wrong local day.
        if (selectedDay) {
            const parts = selectedDay.date.split("-").map(Number);
            return new Date(parts[0], parts[1] - 1, parts[2]);
        }
        return new Date(Date.now() + dayOffset * 86400000);
    }

    // --- Live clock ------------------------------------------------------------
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    implicitWidth: 900
    implicitHeight: mainRow.implicitHeight

    Row {
        id: mainRow
        width: parent.width
        spacing: 24

        // --- Calendar --------------------------------------------------------
        Item {
            width: 230
            height: calCol.implicitHeight

            Column {
                id: calCol
                width: parent.width
                spacing: 10

                Item {
                    width: parent.width
                    height: 26

                    IconButton { icon: "chevron_left"; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; onClicked: root.shiftMonth(-1) }
                    StyledText {
                        anchors.centerIn: parent
                        font.bold: true
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                        font.pixelSize: Config.fontSize - 1
                    }
                    IconButton { icon: "chevron_right"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; onClicked: root.shiftMonth(1) }
                }

                Row {
                    width: parent.width
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        StyledText {
                            required property string modelData
                            width: 230 / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            opacity: 0.5
                            font.pixelSize: Config.fontSize - 3
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.weeks

                        Row {
                            required property var modelData
                            width: calCol.width

                            Repeater {
                                model: parent.modelData

                                Item {
                                    id: cell
                                    required property int modelData
                                    readonly property bool isToday: root.viewingCurrentMonth && modelData === root.today.getDate()

                                    width: 230 / 7
                                    height: width
                                    visible: modelData > 0

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 6
                                        height: width
                                        radius: width / 2
                                        color: cell.isToday ? Colors.accent : (dayHover.hovered ? Colors.overlay : "transparent")
                                        opacity: cell.isToday ? 1 : (dayHover.hovered ? 0.3 : 1)
                                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }
                                    }

                                    HoverHandler { id: dayHover }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: cell.modelData
                                        font.bold: cell.isToday
                                        color: cell.isToday ? Colors.accentText : Colors.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Clock + hourly forecast -------------------------------------------
        Column {
            width: 380
            spacing: 10

            StyledText {
                text: Qt.formatTime(root.now, "hh:mm") + ":" + Qt.formatTime(root.now, "ss")
                font.family: Config.monoFontFamily
                font.bold: true
                font.pixelSize: Config.fontSize + 30
            }
            StyledText {
                text: Qt.formatDate(root.now, "dddd, MMM d")
                opacity: 0.7
            }

            StyledText {
                text: "Coming up"
                font.bold: true
                visible: Weather.hourly.length > 0
                topPadding: 10
            }

            ListView {
                width: parent.width
                height: 84
                visible: Weather.hourly.length > 0
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: Weather.hourly
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    width: 64
                    height: 80
                    radius: 40
                    color: Colors.surface
                    border.width: 1
                    border.color: Colors.overlay

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        StyledText { text: modelData.label; font.pixelSize: Config.fontSize - 4; opacity: 0.6; anchors.horizontalCenter: parent.horizontalCenter }
                        MaterialIcon { icon: modelData.icon; font.pixelSize: 16; color: Colors.accent; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: Math.round(modelData.tempC) + "°"; font.bold: true; font.pixelSize: Config.fontSize - 2; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            StyledText {
                visible: !Weather.available
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.6
                text: Weather.loading ? "Loading…" : "No weather data — set a location in Settings."
            }
        }

        // --- Current conditions -------------------------------------------------
        Column {
            width: 230
            spacing: 12

            Item {
                width: parent.width
                height: 26

                IconButton {
                    icon: "chevron_left"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.dayOffset > 0
                    opacity: enabled ? 1 : 0.3
                    onClicked: root.dayOffset -= 1
                }
                StyledText {
                    anchors.centerIn: parent
                    font.bold: true
                    text: Qt.formatDate(root.selectedDate, "dddd").toUpperCase()
                    font.pixelSize: Config.fontSize - 2
                }
                IconButton {
                    icon: "chevron_right"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.dayOffset < root.maxDayOffset
                    opacity: enabled ? 1 : 0.3
                    onClicked: root.dayOffset += 1
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                visible: Weather.available && root.selectedDay !== null

                StyledText {
                    text: root.selectedDay ? Math.round(root.selectedDay.tempC) + "°" : ""
                    font.bold: true
                    font.pixelSize: Config.fontSize + 34
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.selectedDay ? root.selectedDay.condition : ""
                    opacity: 0.7
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Grid {
                width: parent.width
                columns: 4
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.selectedDay ? [
                        { icon: "air", label: "WIND", value: Math.round(root.selectedDay.windKmph) + "km/h" },
                        { icon: "water_drop", label: "HUMID", value: root.selectedDay.humidity + "%" },
                        { icon: "rainy", label: "RAIN", value: root.selectedDay.chanceOfRain + "%" },
                        { icon: "device_thermostat", label: "FEELS", value: Math.round(root.selectedDay.feelsLikeC) + "°" }
                    ] : []

                    Rectangle {
                        required property var modelData
                        width: (parent.width - 3 * 6) / 4
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: Colors.overlay

                        Column {
                            anchors.centerIn: parent
                            spacing: 1
                            MaterialIcon { icon: modelData.icon; font.pixelSize: 12; opacity: 0.8; anchors.horizontalCenter: parent.horizontalCenter }
                            StyledText { text: modelData.value; font.pixelSize: Config.fontSize - 5; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }
        }
    }
}
