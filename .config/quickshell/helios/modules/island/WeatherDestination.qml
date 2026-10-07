import QtQuick
import "../../services"
import "../../components"

// Current conditions for the selected day, the next hours, and a date picker
// for jumping between forecast days.
Item {
    id: root

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
    readonly property string condition: root.selectedDay ? root.selectedDay.condition : Weather.condition

    // --- Date picker month grid ---
    property bool pickerOpen: false
    property date viewDate: new Date()
    readonly property date today: new Date()

    function openPicker() {
        root.viewDate = root.selectedDate;
        root.pickerOpen = true;
        picker.forceActiveFocus();
    }

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

    function coordinate(value, positive, negative) {
        return Math.abs(value).toFixed(4) + "° " + (value >= 0 ? positive : negative);
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

    onVisibleChanged: if (!visible) pickerOpen = false

    implicitWidth: 660
    implicitHeight: Weather.available ? (contentCol.implicitHeight + 56) : 200

    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Colors.radiusLarge
        color: Colors.surface
        clip: true

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
            anchors.topMargin: 28
            anchors.leftMargin: 30
            anchors.rightMargin: 30
            visible: Weather.available

            // --- Location and day navigation ---
            Item {
                id: header
                width: parent.width
                height: Math.max(placeCol.implicitHeight, dayNav.implicitHeight)

                Column {
                    id: placeCol
                    anchors.left: parent.left
                    anchors.right: dayNav.left
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    spacing: 2

                    StyledText {
                        width: parent.width
                        text: Weather.location || Weather.locationName || "Weather"
                        elide: Text.ElideRight
                        font.pixelSize: Config.fontSize + 1
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        width: parent.width
                        text: root.coordinate(Weather.latitude, "N", "S") + ", " + root.coordinate(Weather.longitude, "E", "W")
                        elide: Text.ElideRight
                        font.pixelSize: Config.fontSize - 4
                        color: Colors.subtext
                    }
                }

                Row {
                    id: dayNav
                    anchors.right: parent.right
                    anchors.rightMargin: -8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    IconButton {
                        objectName: "weatherPreviousDay"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_left"
                        iconColor: Colors.subtext
                        label: "Previous forecast day"
                        enabled: root.dayOffset > 0
                        onClicked: root.dayOffset -= 1
                    }
                    Chip {
                        objectName: "weatherDatePickerButton"
                        anchors.verticalCenter: parent.verticalCenter
                        inactiveTint: "transparent"
                        Accessible.name: "Choose forecast day, " + dayLabel.text
                        onClicked: root.pickerOpen ? root.pickerOpen = false : root.openPicker()

                        StyledText {
                            id: dayLabel
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.dayOffset === 0 ? "Today" : root.dayOffset === 1 ? "Tomorrow" : Qt.formatDate(root.selectedDate, "dddd")
                            font.pixelSize: Config.fontSize - 2
                            font.weight: Font.Medium
                        }
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "expand_more"
                            font.pixelSize: 14
                            color: Colors.subtext
                            rotation: root.pickerOpen ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: Config.reducedMotion ? 0 : Config.animFast; easing.type: Easing.OutCubic } }
                        }
                    }
                    IconButton {
                        objectName: "weatherNextDay"
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "chevron_right"
                        iconColor: Colors.subtext
                        label: "Next forecast day"
                        enabled: root.dayOffset < root.maxDayOffset
                        onClicked: root.dayOffset += 1
                    }
                }
            }

            Item { width: 1; height: 14 }

            // --- Temperature, condition, and icon ---
            Item {
                width: parent.width
                height: temperature.implicitHeight

                StyledText {
                    id: temperature
                    objectName: "weatherHeroTemperature"
                    anchors.left: parent.left
                    anchors.leftMargin: -4
                    text: Weather.formatTemperature(root.selectedDay ? root.selectedDay.tempC : Weather.tempC)
                    font.pixelSize: Config.fontSize + 78
                    font.weight: Font.Medium
                    font.letterSpacing: -2
                }
                Column {
                    anchors.left: temperature.right
                    anchors.leftMargin: 18
                    anchors.right: conditionIcon.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: temperature.verticalCenter
                    anchors.verticalCenterOffset: 6
                    spacing: 4

                    StyledText {
                        width: parent.width
                        text: root.condition
                        font.pixelSize: Config.fontSize + 5
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    StyledText {
                        width: parent.width
                        text: "High " + Weather.formatTemperature(root.selectedDay ? root.selectedDay.maxTempC : Weather.maxTempC)
                            + " · Low " + Weather.formatTemperature(root.selectedDay ? root.selectedDay.minTempC : Weather.minTempC)
                        font.pixelSize: Config.fontSize - 3
                        color: Colors.subtext
                        elide: Text.ElideRight
                    }
                }
                MaterialIcon {
                    id: conditionIcon
                    objectName: "weatherConditionIcon"
                    anchors.right: parent.right
                    anchors.verticalCenter: temperature.verticalCenter
                    anchors.verticalCenterOffset: 6
                    // Day-level forecasts are midday snapshots; only today follows day and night.
                    icon: root.dayOffset === 0 ? Weather.icon : Weather.iconFor(root.condition)
                    font.pixelSize: 44
                    weight: 200
                    color: Colors.subtext
                    Accessible.ignored: true
                }
            }

            Item { width: 1; height: 22 }

            // --- Details ---
            Row {
                width: parent.width
                visible: root.selectedDay !== null

                Repeater {
                    model: root.selectedDay ? [
                        { label: "Feels like", value: Weather.formatTemperature(root.selectedDay.feelsLikeC) },
                        { label: "Chance of rain", value: root.selectedDay.chanceOfRain + "%" },
                        { label: "Humidity", value: root.selectedDay.humidity + "%" },
                        { label: "Wind", value: Weather.formatWind(root.selectedDay.windKmph) }
                    ] : []
                    Column {
                        required property var modelData
                        width: contentCol.width / 4
                        spacing: 4
                        StyledText { text: modelData.label; font.pixelSize: Config.fontSize - 4; color: Colors.subtext }
                        StyledText { text: modelData.value; font.pixelSize: Config.fontSize + 1; font.weight: Font.Medium }
                    }
                }
            }

            Item { width: 1; height: 40; visible: hourly.visible }

            // --- Next hours ---
            Item {
                id: hourly
                width: parent.width
                height: hourRow.y + hourRow.implicitHeight
                visible: Weather.hourly.length > 0
                readonly property var hours: Weather.hourly.slice(0, 7)
                readonly property real columnWidth: width / Math.max(1, hours.length)

                Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }
                Rectangle {
                    // Marks the current hour.
                    x: hourly.columnWidth / 2 - width / 2
                    y: -1
                    width: 28
                    height: 2
                    radius: 1
                    color: Colors.accent
                }

                Row {
                    id: hourRow
                    y: 18

                    Repeater {
                        model: hourly.hours
                        Column {
                            required property var modelData
                            required property int index
                            width: hourly.columnWidth
                            spacing: 8
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: Config.fontSize - 4
                                font.weight: Font.Medium
                                color: index === 0 ? Colors.accent : Colors.subtext
                            }
                            MaterialIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: modelData.icon
                                font.pixelSize: 16
                                weight: 300
                                color: Colors.subtext
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.formatTemperature(modelData.tempC)
                                font.pixelSize: Config.fontSize - 2
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }

        // Clicking anywhere outside the open picker dismisses it.
        MouseArea {
            anchors.fill: parent
            visible: root.pickerOpen
            onClicked: root.pickerOpen = false
        }

        // --- Date picker ---
        Rectangle {
            id: picker
            objectName: "weatherDatePicker"
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 30
            anchors.topMargin: 70
            width: 236
            height: pickerCol.implicitHeight + 28
            radius: Colors.radiusSmall
            color: Colors.surfaceHigh
            visible: opacity > 0
            opacity: root.pickerOpen ? 1 : 0
            scale: root.pickerOpen || Config.reducedMotion ? 1 : 0.96
            transformOrigin: Item.TopRight
            Behavior on opacity { NumberAnimation { duration: Config.reducedMotion ? 0 : Config.animFast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Config.reducedMotion ? 0 : Config.animFast; easing.type: Easing.OutCubic } }
            Keys.onEscapePressed: event => { root.pickerOpen = false; event.accepted = true; }

            // Swallow clicks so they don't reach the dismiss area behind.
            MouseArea { anchors.fill: parent }

            Column {
                id: pickerCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 14
                spacing: 6

                Item {
                    width: parent.width
                    height: 26

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                        font.pixelSize: Config.fontSize - 1
                        font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        IconButton {
                            icon: "chevron_left"
                            iconSize: 14
                            iconColor: Colors.subtext
                            implicitWidth: 26
                            implicitHeight: 26
                            label: "Previous month"
                            onClicked: root.shiftMonth(-1)
                        }
                        IconButton {
                            icon: "chevron_right"
                            iconSize: 14
                            iconColor: Colors.subtext
                            implicitWidth: 26
                            implicitHeight: 26
                            label: "Next month"
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                Row {
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        StyledText {
                            required property string modelData
                            width: pickerCol.width / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.pixelSize: Config.fontSize - 5
                            font.weight: Font.Medium
                            color: Colors.subtext
                        }
                    }
                }

                Column {
                    Repeater {
                        model: root.weeks

                        Row {
                            required property var modelData

                            Repeater {
                                model: parent.modelData

                                Item {
                                    id: cell
                                    required property int modelData
                                    readonly property bool isToday: root.viewingCurrentMonth && modelData === root.today.getDate()
                                    readonly property int diffFromToday: root.daysFromToday(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData)
                                    readonly property bool hasForecast: modelData > 0 && diffFromToday >= 0 && diffFromToday <= root.maxDayOffset
                                    readonly property bool isSelected: hasForecast && diffFromToday === root.dayOffset

                                    width: pickerCol.width / 7
                                    height: 28
                                    // Blank pad cells keep their column; `visible` would shift the month left.
                                    opacity: modelData > 0 ? 1 : 0
                                    enabled: hasForecast
                                    activeFocusOnTab: hasForecast
                                    Accessible.role: Accessible.Button
                                    Accessible.name: Qt.formatDate(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), Math.max(1, modelData)), "MMMM d")
                                    Accessible.onPressAction: cell.choose()
                                    Keys.onReturnPressed: cell.choose()
                                    Keys.onSpacePressed: cell.choose()

                                    function choose() {
                                        root.dayOffset = cell.diffFromToday;
                                        root.pickerOpen = false;
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 26
                                        height: 26
                                        radius: width / 2
                                        color: cell.isToday ? Colors.accent
                                            : dayMouse.containsMouse ? Qt.alpha(Colors.overlay, 0.2) : "transparent"
                                        border.width: cell.activeFocus || (cell.isSelected && !cell.isToday) ? 1 : 0
                                        border.color: cell.isToday ? Colors.accentText : Colors.accent
                                    }
                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: cell.choose()
                                    }
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: cell.modelData
                                        font.pixelSize: Config.fontSize - 3
                                        font.weight: cell.isToday ? Font.Bold : Font.Normal
                                        color: cell.isToday ? Colors.accentText : Colors.text
                                        opacity: cell.hasForecast ? 1 : 0.45
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
