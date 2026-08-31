import QtQuick
import "../../services"
import "../../components"

// Immersive weather panel — one full-bleed surface instead of separate
// card zones. Clock and hero conditions float top-left/top-right over a
// weather-effect backdrop; a compact calendar tile and hourly strip float
// bottom-left/bottom-right as translucent glass over the same art.
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

    implicitWidth: 660
    implicitHeight: Weather.available ? (contentCol.implicitHeight + 24) : 200

    // ═══════════════════════════════════════════════════════════════════
    // BACKDROP — one continuous surface, weather effect fills it entirely
    // ═══════════════════════════════════════════════════════════════════
    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Colors.radiusLarge
        clip: true

        gradient: Gradient {
            GradientStop { position: 0.0; color: Colors.surfaceHigh }
            GradientStop { position: 0.55; color: Colors.surface }
            GradientStop { position: 1.0; color: Colors.background }
        }

        WeatherEffectMini {
            anchors.fill: parent
            opacity: 0.65
        }

        StyledText {
            visible: !Weather.available
            anchors.centerIn: parent
            width: parent.width - 80
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Colors.subtext
            text: Weather.loading ? "Loading weather data…" : "No weather data — set a location in Settings."
        }

        Column {
            id: contentCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 10
            visible: Weather.available

            // ═══════════════════════════════════════════════════════════
            // TOP ROW — clock (left) / hero conditions + stats (right)
            // ═══════════════════════════════════════════════════════════
            Item {
                width: parent.width
                height: Math.max(clockCol.implicitHeight, heroCol.implicitHeight)

                Column {
                    id: clockCol
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    StyledText {
                        text: Qt.formatTime(root.now, Config.timeFormat)
                        font.family: Config.monoFontFamily
                        font.pixelSize: Config.fontSize + 20
                        font.weight: Font.Light
                    }
                    StyledText {
                        text: Qt.formatDate(root.now, "dddd, MMMM d")
                        font.pixelSize: Config.fontSize
                        color: Colors.subtext
                    }
                }

                Column {
                    id: heroCol
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Day navigator
                    Item {
                        width: navRow.implicitWidth
                        height: 22
                        anchors.right: parent.right

                        Row {
                            id: navRow
                            anchors.centerIn: parent
                            spacing: 4

                            IconButton {
                                icon: "chevron_left"
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: root.dayOffset > 0
                                opacity: enabled ? 1 : 0.3
                                onClicked: root.dayOffset -= 1
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                font.weight: Font.DemiBold
                                font.pixelSize: Config.fontSize - 1
                                font.capitalization: Font.AllUppercase
                                color: Colors.subtext
                                text: root.dayOffset === 0 ? "Today"
                                    : root.dayOffset === 1 ? "Tomorrow"
                                    : Qt.formatDate(root.selectedDate, "dddd")
                            }
                            IconButton {
                                icon: "chevron_right"
                                anchors.verticalCenter: parent.verticalCenter
                                enabled: root.dayOffset < root.maxDayOffset
                                opacity: enabled ? 1 : 0.3
                                onClicked: root.dayOffset += 1
                            }
                        }
                    }

                    // Hero temperature
                    Column {
                        anchors.right: parent.right
                        spacing: 0
                        visible: root.selectedDay !== null

                        StyledText {
                            anchors.right: parent.right
                            text: root.selectedDay ? Math.round(root.selectedDay.tempC) + "°" : ""
                            font.pixelSize: Config.fontSize + 22
                            font.weight: Font.Thin
                        }
                        StyledText {
                            anchors.right: parent.right
                            text: root.selectedDay ? root.selectedDay.condition : ""
                            font.pixelSize: Config.fontSize
                            color: Colors.subtext
                        }
                    }

                    // Borderless stat row — floats directly on the backdrop
                    Row {
                        anchors.right: parent.right
                        spacing: 14
                        visible: root.selectedDay !== null

                        Repeater {
                            model: root.selectedDay ? [
                                { icon: "air", value: Math.round(root.selectedDay.windKmph) + " km/h" },
                                { icon: "water_drop", value: root.selectedDay.humidity + "%" },
                                { icon: "rainy", value: root.selectedDay.chanceOfRain + "%" },
                                { icon: "device_thermostat", value: Math.round(root.selectedDay.feelsLikeC) + "°" }
                            ] : []

                            Row {
                                required property var modelData
                                spacing: 4

                                MaterialIcon {
                                    icon: modelData.icon
                                    font.pixelSize: 14
                                    color: Colors.accent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                StyledText {
                                    text: modelData.value
                                    font.pixelSize: Config.fontSize - 2
                                    color: Colors.subtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════════════════════════
            // BOTTOM ROW — mini calendar tile (left) / hourly strip (right)
            // ═══════════════════════════════════════════════════════════
            Item {
                width: parent.width
                height: Math.max(calTile.height, hourlyCol.implicitHeight)

                // --- Mini calendar glass tile ---
                Rectangle {
                    id: calTile
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: 180
                    height: calCol.implicitHeight + 14
                    radius: Colors.radiusSmall
                    color: Colors.surfaceHigh
                    opacity: 0.75

                    Column {
                        id: calCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 7
                        spacing: 3

                        // Month header with navigation
                        Item {
                            width: parent.width
                            height: 18

                            IconButton {
                                icon: "chevron_left"
                                iconSize: 11
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 18
                                implicitHeight: 18
                                onClicked: root.shiftMonth(-1)
                            }
                            StyledText {
                                anchors.centerIn: parent
                                font.weight: Font.DemiBold
                                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                                font.pixelSize: Config.fontSize - 4
                            }
                            IconButton {
                                icon: "chevron_right"
                                iconSize: 11
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitWidth: 18
                                implicitHeight: 18
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
                                    width: (calCol.width) / 7
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData
                                    font.pixelSize: Config.fontSize - 6
                                    font.weight: Font.Medium
                                    color: Colors.subtext
                                }
                            }
                        }

                        // Day grid
                        Column {
                            width: parent.width
                            spacing: 1

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
                                            readonly property int diffFromToday: root.daysFromToday(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData)
                                            readonly property bool isForecastLinkable: !cell.isToday && cell.diffFromToday >= 0 && cell.diffFromToday <= root.maxDayOffset
                                            readonly property bool isSelectedForecastDay: !cell.isToday && cell.diffFromToday === root.dayOffset

                                            width: calCol.width / 7
                                            height: width
                                            // Blank pad cells must keep their
                                            // column (see CalendarTab.qml) —
                                            // `visible` would collapse them
                                            // and shift the month left.
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

                                            // Selected forecast day: outline ring
                                            Rectangle {
                                                visible: cell.isSelectedForecastDay
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
                                                enabled: cell.isForecastLinkable
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.dayOffset = cell.diffFromToday
                                            }

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: cell.modelData
                                                font.pixelSize: Config.fontSize - 6
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

                // --- Hourly forecast strip ---
                Column {
                    id: hourlyCol
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 400
                    spacing: 6
                    visible: Weather.hourly.length > 0

                    StyledText {
                        anchors.right: parent.right
                        text: "Hourly Forecast"
                        font.pixelSize: Config.fontSize - 2
                        font.weight: Font.DemiBold
                        color: Colors.subtext
                        font.capitalization: Font.AllUppercase
                    }

                    ListView {
                        width: parent.width
                        height: 78
                        orientation: ListView.Horizontal
                        spacing: 6
                        clip: true
                        model: Weather.hourly
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 52
                            height: 74
                            radius: 26
                            color: index === 0 ? Colors.accent : Colors.surfaceHigh
                            opacity: index === 0 ? 1 : 0.75

                            Column {
                                anchors.centerIn: parent
                                spacing: 4
                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Config.fontSize - 5
                                    font.weight: Font.Medium
                                    color: index === 0 ? Colors.accentText : Colors.subtext
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                MaterialIcon {
                                    icon: modelData.icon
                                    font.pixelSize: 15
                                    color: index === 0 ? Colors.accentText : Colors.accent
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                StyledText {
                                    text: Math.round(modelData.tempC) + "°"
                                    font.pixelSize: Config.fontSize - 3
                                    font.weight: Font.DemiBold
                                    color: index === 0 ? Colors.accentText : Colors.text
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
