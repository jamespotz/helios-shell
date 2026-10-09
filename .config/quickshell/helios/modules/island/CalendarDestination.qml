import QtQuick
import Quickshell
import "../../services"
import "../../components"

// Real month calendar + agenda, backed by services/Calendar.qml. The
// today/selected/hover cell states below intentionally mirror
// WeatherDestination.qml's forecast mini-grid (same visual language, per
// AGENTS.md's "reuse existing interaction patterns") — the grid math
// itself is a small, deliberate duplication rather than a shared helper,
// since WeatherDestination's version is entangled with forecast-day-selection
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

    readonly property var calendar: Calendar.state
    readonly property var eventsByDate: root.calendar.eventsByDate
    readonly property var selectedDayEvents: root.eventsByDate[root.dateKey(root.selectedDate)] || []

    // "Today · 3 events" under the agenda title. While a refresh is still
    // fetching (network subscriptions, up to 10s each), an empty day reads
    // "Loading…" rather than "No events".
    readonly property string agendaSummary: {
        const n = root.selectedDayEvents.length;
        if (n === 0 && !root.calendar.ready) return "Loading…";
        const count = n === 0 ? "No events" : n === 1 ? "1 event" : n + " events";
        const sel = root.selectedDate, now = root.today;
        const days = Math.round((new Date(sel.getFullYear(), sel.getMonth(), sel.getDate())
            - new Date(now.getFullYear(), now.getMonth(), now.getDate())) / 86400000);
        const relative = days === 0 ? "Today" : days === 1 ? "Tomorrow" : days === -1 ? "Yesterday" : "";
        return relative ? relative + " · " + count : count;
    }

    // The agenda has no scrollbar, so Tab focus scrolls the focused item into view.
    function revealInAgenda(item) {
        const y = item.mapToItem(eventsCol, 0, 0).y;
        if (y < eventsFlick.contentY) eventsFlick.contentY = y;
        else if (y + item.height > eventsFlick.contentY + eventsFlick.height) eventsFlick.contentY = y + item.height - eventsFlick.height;
    }

    readonly property var dotPalette: [Colors.accent, Colors.success, Colors.tertiary, Colors.secondary, Colors.warning]
    function dotColor(id) {
        let hash = 0;
        for (let i = 0; i < id.length; i++) hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
        return root.dotPalette[hash % root.dotPalette.length];
    }

    Component.onCompleted: Calendar.setActive(true)
    Component.onDestruction: Calendar.setActive(false)

    implicitWidth: 640
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // --- Title bar -----------------------------------------------------
        Item {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                MaterialIcon { icon: "calendar_today"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    font.weight: Font.DemiBold
                    font.pixelSize: Config.fontSize + 2
                    text: "Calendar"
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconButton {
                    icon: "add"
                    onClicked: root.manageOpen = !root.manageOpen
                }
            }
        }

        // --- Manage calendars (subscriptions) --------------------------------
        Column {
            width: parent.width
            spacing: 12
            visible: root.manageOpen
            height: root.manageOpen ? implicitHeight : 0
            clip: true

            // --- Add a calendar ----------------------------------------------
            Column {
                width: parent.width
                spacing: 8

                StyledText { text: "Add a calendar"; font.pixelSize: Config.fontSize - 2; opacity: 0.7 }

                Row {
                    width: parent.width
                    spacing: 8

                    SearchField {
                        id: urlField
                        width: parent.width - connectButton.width - 8
                        icon: "link"
                        placeholder: "webcal:// or https:// link to an .ics feed"
                        onAccepted: connectButton.clicked()
                        onEscapePressed: IslandNavigation.closeMain()
                    }
                    PrimaryButton {
                        id: connectButton
                        width: 90
                        height: urlField.height
                        text: root.calendar.refreshing ? "" : "Connect"
                        active: true
                        enabled: !root.calendar.refreshing && urlField.text.trim().length > 0
                        onClicked: {
                            const url = urlField.text.trim();
                            Calendar.subscribe(Calendar.defaultSubscriptionLabel(url), url);
                            urlField.text = "";
                        }

                        LoadingSpinner {
                            visible: root.calendar.refreshing
                            active: root.calendar.refreshing
                            font.pixelSize: 16
                            color: Colors.accentText
                        }
                    }
                }
            }

            StyledText {
                visible: root.calendar.subscriptions.length === 0
                text: "No subscribed calendars yet"
                opacity: 0.5
                font.pixelSize: Config.fontSize - 2
            }

            Column {
                width: parent.width
                spacing: 4
                visible: root.calendar.subscriptions.length > 0

                Repeater {
                    model: root.calendar.subscriptions

                    Item {
                        id: subRow
                        required property var modelData
                        readonly property var error: subRow.modelData.error

                        width: parent.width
                        height: 40

                        Row {
                            anchors.fill: parent
                            spacing: 10

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.dotColor(subRow.modelData.id)
                            }

                            Column {
                                // Row spacing (10) applies between all four children
                                // (dot, this column, toggle, close button) — three gaps.
                                width: parent.width - 8 - 42 - 30 - 3 * 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Row {
                                    width: parent.width
                                    spacing: 4

                                    MaterialIcon {
                                        visible: !!subRow.error
                                        icon: "warning"
                                        font.pixelSize: 12
                                        color: Colors.warning
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    StyledText {
                                        width: subRow.error ? parent.width - 16 : parent.width
                                        elide: Text.ElideRight
                                        text: subRow.modelData.label
                                    }
                                }
                                StyledText {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: subRow.error ? subRow.error.message : Calendar.providerLabel(subRow.modelData.url)
                                    color: subRow.error ? Colors.warning : Colors.subtext
                                    font.pixelSize: Config.fontSize - 4
                                }
                            }

                            Toggle {
                                anchors.verticalCenter: parent.verticalCenter
                                checked: subRow.modelData.enabled
                                onToggled: checked => Calendar.setSubscriptionEnabled(subRow.modelData.id, checked)
                            }
                            IconButton {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "close"
                                iconSize: 14
                                onClicked: Calendar.unsubscribe(subRow.modelData.id)
                            }
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.15 }

            // --- Auto-focus for meetings -----------------------------------
            Column {
                width: parent.width
                spacing: 6

                StyledText { text: "When a meeting starts"; font.pixelSize: Config.fontSize - 2; opacity: 0.7 }

                SegmentedControl {
                    width: parent.width
                    model: [{ value: "", label: "Off", icon: "" }].concat(FocusModes.presets.map(p => ({ value: p.id, label: p.name, icon: p.icon })))
                    currentValue: Calendar.meetingFocusId
                    onActivated: value => Calendar.setMeetingFocusId(value)
                }
            }
        }

        // --- Agenda for selected day (left) | month grid (right) -------------
        Row {
            width: parent.width
            spacing: 16

            // --- Agenda for selected day -----------------------------------------
            Column {
                id: agendaCol
                width: parent.width - monthCol.width - 1 - parent.spacing * 2
                height: monthCol.height
                spacing: 12

                Column {
                    id: agendaHeader
                    width: parent.width
                    spacing: 4

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Config.fontSize + 6
                        font.weight: Font.Bold
                        text: root.selectedDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    }
                    StyledText {
                        width: parent.width
                        text: root.agendaSummary
                        color: Colors.subtext
                        font.pixelSize: Config.fontSize - 2
                    }
                }

                // Capped to the month grid's height; scrolls without a visible bar.
                Flickable {
                    id: eventsFlick
                    width: parent.width
                    height: parent.height - agendaHeader.height - parent.spacing
                    visible: root.selectedDayEvents.length > 0
                    contentWidth: width
                    contentHeight: eventsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: eventsCol
                        width: parent.width

                        Repeater {
                            model: root.selectedDayEvents

                            Item {
                                id: eventRow
                                required property var modelData
                                required property int index
                                readonly property var links: eventRow.modelData.links || []
                                property bool linksOpen: false

                                width: parent.width
                                height: eventBody.implicitHeight + 24

                                Rectangle {
                                    visible: eventRow.index > 0
                                    width: parent.width
                                    height: 1
                                    color: Colors.overlay
                                    opacity: 0.15
                                }

                                Row {
                                    id: eventBody
                                    y: 12
                                    width: parent.width
                                    spacing: 16

                                    StyledText {
                                        width: 48
                                        text: eventRow.modelData.allDay ? "All day" : (eventRow.modelData.startTime || "")
                                        color: Colors.subtext
                                        font.pixelSize: Config.fontSize - 1
                                        font.family: Config.monoFontFamily
                                    }
                                    Column {
                                        width: parent.width - 48 - parent.spacing
                                        spacing: 8

                                        StyledText {
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            font.pixelSize: Config.fontSize + 1
                                            font.weight: Font.DemiBold
                                            text: eventRow.modelData.summary
                                        }

                                        // Links stay collapsed behind a count so long
                                        // meeting invites don't bury the next event.
                                        Item {
                                            id: linksToggle
                                            Accessible.role: Accessible.Button
                                            Accessible.name: eventRow.links.length + " links"
                                            Accessible.onPressAction: linksToggle.clicked()
                                            signal clicked()
                                            onClicked: { AlertSounds.play("tap"); eventRow.linksOpen = !eventRow.linksOpen; }
                                            visible: eventRow.links.length > 0
                                            width: linksToggleRow.implicitWidth
                                            height: 22
                                            activeFocusOnTab: true
                                            opacity: linksHover.hovered || linksToggle.activeFocus ? 1 : 0.85

                                            Row {
                                                id: linksToggleRow
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 6

                                                MaterialIcon {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    icon: eventRow.linksOpen ? "expand_less" : "chevron_right"
                                                    font.pixelSize: 16
                                                    color: Colors.subtext
                                                }
                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: eventRow.links.length
                                                    color: Colors.accent
                                                    font.weight: Font.Bold
                                                    font.pixelSize: Config.fontSize - 2
                                                }
                                                StyledText {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: eventRow.links.length === 1 ? "link" : "links"
                                                    color: Colors.subtext
                                                    font.pixelSize: Config.fontSize - 2
                                                    font.underline: linksToggle.activeFocus
                                                }
                                            }

                                            HoverHandler { id: linksHover; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: linksToggle.clicked() }
                                            Keys.onReturnPressed: linksToggle.clicked()
                                            Keys.onSpacePressed: linksToggle.clicked()
                                            onActiveFocusChanged: if (activeFocus) root.revealInAgenda(linksToggle)
                                        }

                                        Column {
                                            width: parent.width
                                            visible: eventRow.linksOpen

                                            Repeater {
                                                model: eventRow.linksOpen ? eventRow.links : []

                                                Item {
                                                    id: linkItem
                                                    Accessible.role: Accessible.Link
                                                    Accessible.name: linkItem.modelData.label || linkItem.modelData.url
                                                    Accessible.onPressAction: linkItem.clicked()
                                                    signal clicked()
                                                    onClicked: {
                                                        AlertSounds.play("tap");
                                                        Quickshell.execDetached(["xdg-open", linkItem.modelData.url]);
                                                    }
                                                    required property var modelData
                                                    readonly property string host: linkItem.modelData.url.split("/")[2] || ""
                                                    width: parent.width
                                                    height: 28
                                                    activeFocusOnTab: true

                                                    StyledText {
                                                        anchors.left: parent.left
                                                        anchors.right: hostText.left
                                                        anchors.rightMargin: 12
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        elide: Text.ElideRight
                                                        text: linkItem.modelData.label || linkItem.host
                                                        font.pixelSize: Config.fontSize - 1
                                                        font.underline: linkHover.hovered || linkItem.activeFocus
                                                    }
                                                    StyledText {
                                                        id: hostText
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: Math.min(implicitWidth, parent.width / 2)
                                                        elide: Text.ElideLeft
                                                        visible: !!linkItem.modelData.label
                                                        text: linkItem.host
                                                        color: Colors.subtext
                                                        font.pixelSize: Config.fontSize - 2
                                                    }

                                                    HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler {
                                                        onTapped: linkItem.clicked()
                                                    }
                                                    Keys.onReturnPressed: linkItem.clicked()
                                                    Keys.onSpacePressed: linkItem.clicked()
                                                    onActiveFocusChanged: if (activeFocus) root.revealInAgenda(linkItem)
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

            Rectangle { width: 1; height: monthCol.height; color: Colors.overlay; opacity: 0.15 }

            Column {
                id: monthCol
                width: 300
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
                            width: monthCol.width / 7
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
                            width: monthCol.width

                            Repeater {
                                model: parent.modelData

                                Item {
                                    id: cell
                                    Accessible.role: Accessible.Button
                                    Accessible.name: cell.cellDate.toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                                    Accessible.onPressAction: if (modelData > 0) cell.clicked()
                                    signal clicked()
                                    onClicked: { AlertSounds.play("tap"); root.selectedDate = cell.cellDate; }
                                    activeFocusOnTab: visible && modelData > 0
                                    Keys.onReturnPressed: cell.clicked()
                                    Keys.onSpacePressed: cell.clicked()
                                    required property int modelData
                                    readonly property date cellDate: new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), modelData || 1)
                                    readonly property string cellKey: root.dateKey(cell.cellDate)
                                    readonly property bool isToday: root.viewingCurrentMonth && modelData === root.today.getDate()
                                    readonly property bool isSelected: modelData > 0
                                        && cell.cellDate.getFullYear() === root.selectedDate.getFullYear()
                                        && cell.cellDate.getMonth() === root.selectedDate.getMonth()
                                        && cell.cellDate.getDate() === root.selectedDate.getDate()
                                    readonly property bool hasEvents: modelData > 0 && !!root.eventsByDate[cell.cellKey]

                                    width: monthCol.width / 7
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
                                        onClicked: cell.clicked()
                                    }

                                    StyledText {
                                        id: dayNumber
                                        anchors.centerIn: parent
                                        text: cell.modelData
                                        font.underline: cell.activeFocus
                                        font.pixelSize: Config.fontSize - 3
                                        font.weight: Font.Bold
                                        color: cell.isToday ? Colors.accentText : Colors.text
                                    }

                                    // Event indicator dot
                                    Rectangle {
                                        visible: cell.hasEvents
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: dayNumber.bottom
                                        anchors.topMargin: 1
                                        width: 4; height: 4; radius: 2
                                        color: cell.isToday ? Colors.accentText : Colors.accent
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
