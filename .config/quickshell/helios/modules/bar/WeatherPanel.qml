import QtQuick
import "../../services"
import "../../components"

// Apple Weather widget-inspired panel — three distinct card-like zones:
// 1. Calendar (left) — clean grid with today highlight
// 2. Clock + Hourly forecast (center) — large time, scrolling conditions
// 3. Current conditions (right) — hero temperature + stat tiles
//
// Design principles: generous whitespace, clear typographic hierarchy,
// rounded card containers for stat groups, muted secondary text.
Item {
    id: root

    // --- Calendar month grid ---
    property date viewDate: new Date()
    readonly property date today: new Date()

    function shiftMonth(delta) {
        const d = new Date(root.viewDate);
        d.setDate(1);
        d.setMonth(d.getMonth() + delta);
        root.viewDate = d;
    }

    function daysFromToday(year, month, day) {
        const cellDate = new Date(year, month, day);
        const t = new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate());
        return Math.round((cellDate - t) / 86400000);
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

    // --- Day navigator for forecast ---
    property int dayOffset: 0
    readonly property int maxDayOffset: Math.max(0, Weather.daily.length - 1)
    onMaxDayOffsetChanged: dayOffset = Math.min(dayOffset, maxDayOffset)
    readonly property var selectedDay: Weather.daily.length > dayOffset ? Weather.daily[dayOffset] : null
    readonly property date selectedDate: {
        if (selectedDay) {
            const parts = selectedDay.date.split("-").map(Number);
            return new Date(parts[0], parts[1] - 1, parts[2]);
        }
        return new Date(Date.now() + dayOffset * 86400000);
    }

    // --- Live clock ---
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    implicitWidth: 880
    implicitHeight: mainRow.implicitHeight

    Row {
        id: mainRow
        width: parent.width
        spacing: 16

        // ═══════════════════════════════════════════════════════════════════
        // CALENDAR CARD
        // ═══════════════════════════════════════════════════════════════════
        Rectangle {
            width: 240
            height: calCol.implicitHeight + 24
            radius: Colors.radiusLarge
            color: Colors.surfaceHigh
            opacity: 0.6

            Column {
                id: calCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Month header with navigation
                Item {
                    width: parent.width
                    height: 28

                    IconButton {
                        icon: "chevron_left"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.shiftMonth(-1)
                    }
                    StyledText {
                        anchors.centerIn: parent
                        font.weight: Font.DemiBold
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                        font.pixelSize: Config.fontSize
                    }
                    IconButton {
                        icon: "chevron_right"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.shiftMonth(1)
                    }
                }

                // Day-of-week headers
                Row {
                    width: parent.width
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        StyledText {
                            required property string modelData
                            width: (calCol.width - 24) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: Config.fontSize - 3
                            font.weight: Font.Medium
                            color: Colors.subtext
                        }
                    }
                }

                // Day grid
                Column {
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: root.weeks

                        Row {
                            required property var modelData
                            width: calCol.width - 24

                            Repeater {
                                model: parent.modelData

                                Item {
                                    id: cell
                                    required property int modelData
                                    readonly property bool isToday: root.viewingCurrentMonth && modelData === root.today.getDate()
                                    readonly property int diffFromToday: root.daysFromToday(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData)
                                    readonly property bool isForecastLinkable: !cell.isToday && cell.diffFromToday >= 0 && cell.diffFromToday <= root.maxDayOffset
                                    readonly property bool isSelectedForecastDay: !cell.isToday && cell.diffFromToday === root.dayOffset

                                    width: (calCol.width - 24) / 7
                                    height: width
                                    visible: modelData > 0

                                    // Today: solid accent circle
                                    Rectangle {
                                        visible: cell.isToday
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 6
                                        height: width
                                        radius: width / 2
                                        color: Colors.accent
                                    }

                                    // Selected forecast day: outline ring
                                    Rectangle {
                                        visible: cell.isSelectedForecastDay
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 4
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: Colors.accent
                                    }

                                    // Hover state
                                    Rectangle {
                                        visible: !cell.isToday && dayHover.hovered
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width, parent.height) - 6
                                        height: width
                                        radius: width / 2
                                        color: Colors.overlay
                                        opacity: 0.2
                                    }

                                    HoverHandler { id: dayHover }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: cell.isForecastLinkable
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.dayOffset = cell.diffFromToday
                                    }

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: cell.modelData
                                        font.pixelSize: Config.fontSize - 2
                                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                                        color: cell.isToday ? Colors.accentText : Colors.text
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // CLOCK + HOURLY FORECAST
        // ═══════════════════════════════════════════════════════════════════
        Column {
            width: 360
            spacing: 14

            // Large clock — Apple Weather style: clean, prominent
            Column {
                spacing: 2
                StyledText {
                    text: Qt.formatTime(root.now, "h:mm")
                    font.family: Config.monoFontFamily
                    font.pixelSize: Config.fontSize + 32
                    font.weight: Font.Light
                }
                StyledText {
                    text: Qt.formatDate(root.now, "dddd, MMMM d")
                    font.pixelSize: Config.fontSize
                    color: Colors.subtext
                }
            }

            // Hourly forecast — horizontal scrolling pills
            Column {
                width: parent.width
                spacing: 8
                visible: Weather.hourly.length > 0

                StyledText {
                    text: "Hourly Forecast"
                    font.pixelSize: Config.fontSize - 1
                    font.weight: Font.DemiBold
                    color: Colors.subtext
                    font.capitalization: Font.AllUppercase
                    // Apple uses uppercase small labels for section headers
                }

                ListView {
                    width: parent.width
                    height: 90
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    model: Weather.hourly
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 60
                        height: 86
                        radius: 30
                        color: index === 0 ? Colors.accent : Colors.surfaceHigh
                        opacity: index === 0 ? 1 : 0.6

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Config.fontSize - 3
                                font.weight: Font.Medium
                                color: index === 0 ? Colors.accentText : Colors.subtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            MaterialIcon {
                                icon: modelData.icon
                                font.pixelSize: 18
                                color: index === 0 ? Colors.accentText : Colors.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                text: Math.round(modelData.tempC) + "°"
                                font.pixelSize: Config.fontSize - 1
                                font.weight: Font.DemiBold
                                color: index === 0 ? Colors.accentText : Colors.text
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: !Weather.available
                width: parent.width
                wrapMode: Text.WordWrap
                color: Colors.subtext
                text: Weather.loading ? "Loading weather data…" : "No weather data — set a location in Settings."
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // CURRENT CONDITIONS CARD
        // ═══════════════════════════════════════════════════════════════════
        Column {
            width: 220
            spacing: 14

            // Day navigator
            Item {
                width: parent.width
                height: 28

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
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize - 1
                    font.capitalization: Font.AllUppercase
                    text: root.dayOffset === 0 ? "Today"
                        : root.dayOffset === 1 ? "Tomorrow"
                        : Qt.formatDate(root.selectedDate, "dddd")
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

            // Hero temperature — Apple Weather's huge centered temp
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                visible: Weather.available && root.selectedDay !== null

                StyledText {
                    text: root.selectedDay ? Math.round(root.selectedDay.tempC) + "°" : ""
                    font.pixelSize: Config.fontSize + 38
                    font.weight: Font.Thin
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                StyledText {
                    text: root.selectedDay ? root.selectedDay.condition : ""
                    font.pixelSize: Config.fontSize
                    color: Colors.subtext
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Stat tiles — 2x2 grid of rounded cards (Apple Weather detail style)
            Grid {
                width: parent.width
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: root.selectedDay ? [
                        { icon: "air", label: "Wind", value: Math.round(root.selectedDay.windKmph) + " km/h" },
                        { icon: "water_drop", label: "Humidity", value: root.selectedDay.humidity + "%" },
                        { icon: "rainy", label: "Rain", value: root.selectedDay.chanceOfRain + "%" },
                        { icon: "device_thermostat", label: "Feels Like", value: Math.round(root.selectedDay.feelsLikeC) + "°" }
                    ] : []

                    Rectangle {
                        required property var modelData
                        width: (parent.width - 8) / 2
                        height: 72
                        radius: Colors.radiusSmall
                        color: Colors.surfaceHigh
                        opacity: 0.5

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialIcon {
                                icon: modelData.icon
                                font.pixelSize: 16
                                color: Colors.accent
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                text: modelData.value
                                font.pixelSize: Config.fontSize
                                font.weight: Font.DemiBold
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Config.fontSize - 3
                                color: Colors.subtext
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
