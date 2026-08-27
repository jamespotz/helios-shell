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

    // --- App list view state ------------------------------------------------
    property bool searchOpen: false
    property string searchQuery: ""
    property string viewMode: "apps" // "apps" | "category"
    property bool showAllApps: false
    property string expandedApp: "" // app `cls` currently expanded, or ""

    readonly property int visibleAppCount: 4

    readonly property var filteredApps: root.searchQuery.length === 0 ? root.selectedApps
        : root.selectedApps.filter(a => a.name.toLowerCase().includes(root.searchQuery.toLowerCase()))

    readonly property var visibleApps: (root.showAllApps || root.searchQuery.length > 0)
        ? root.filteredApps : root.filteredApps.slice(0, root.visibleAppCount)

    // Category rollup of the selected day's apps, sorted by time descending.
    // Color is resolved at the render site (Activity.categoryColorFor), not
    // baked in here — see the app-row fix below for why.
    readonly property var categoryGroups: {
        const groups = {};
        root.selectedApps.forEach(a => {
            if (!groups[a.category]) groups[a.category] = { name: a.category, seconds: 0, count: 0 };
            groups[a.category].seconds += a.seconds;
            groups[a.category].count += 1;
        });
        return Object.values(groups).sort((a, b) => b.seconds - a.seconds);
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

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "search"
                active: root.searchOpen
                onClicked: {
                    root.searchOpen = !root.searchOpen;
                    if (root.searchOpen) searchField.focusInput();
                    // searchField.text: root.searchQuery (below) is a one-time
                    // binding that typing severs, so closing has to clear the
                    // field itself too — not just the query — or reopening
                    // shows stale text next to an already-unfiltered list.
                    else searchField.text = "";
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

        // --- Search --------------------------------------------------------
        SearchField {
            id: searchField
            width: parent.width
            visible: root.searchOpen
            placeholder: "Filter apps…"
            text: root.searchQuery
            onTextChanged: root.searchQuery = text
            onEscapePressed: { root.searchOpen = false; searchField.text = ""; }
        }

        // --- Apps head: view tabs + total --------------------------------------
        Item {
            width: parent.width
            height: 24

            Row {
                anchors.left: parent.left
                spacing: 18

                Repeater {
                    model: [
                        { value: "apps", label: "By app" },
                        { value: "category", label: "By category" }
                    ]

                    Column {
                        id: viewTab
                        required property var modelData
                        readonly property bool active: root.viewMode === viewTab.modelData.value
                        spacing: 6

                        StyledText {
                            text: viewTab.modelData.label
                            font.bold: viewTab.active
                            opacity: viewTab.active ? 1 : 0.55
                            font.pixelSize: Config.fontSize - 1
                        }
                        Rectangle {
                            width: parent.width
                            height: 2
                            radius: 1
                            color: viewTab.active ? Colors.accent : "transparent"
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.viewMode = viewTab.modelData.value
                        }
                    }
                }
            }

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.selectedTotalText + " total"
                opacity: 0.5
                font.pixelSize: Config.fontSize - 3
            }
        }

        // --- By app ----------------------------------------------------------
        Column {
            width: parent.width
            spacing: 14
            visible: root.viewMode === "apps"

            StyledText {
                visible: root.filteredApps.length === 0
                text: root.selectedApps.length === 0 ? "No activity tracked for this day" : "No apps match your search"
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
            }

            Repeater {
                model: root.visibleApps

                Column {
                    id: appRow
                    required property var modelData
                    readonly property bool expanded: root.expandedApp === appRow.modelData.cls
                    // Resolved here (not baked into Activity.appsFor's model)
                    // so a theme's color animation just updates this binding
                    // in place instead of invalidating selectedApps and
                    // tearing down/rebuilding every app row.
                    readonly property color appColor: Activity.categoryColorFor(appRow.modelData.category)

                    width: parent.width
                    spacing: 8

                    Column {
                        width: parent.width
                        spacing: 6

                        Item {
                            width: parent.width
                            height: 30

                            Row {
                                anchors.left: parent.left
                                anchors.right: chevron.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 10

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: Colors.radiusSmall
                                    color: appRow.appColor
                                    anchors.verticalCenter: parent.verticalCenter

                                    MaterialIcon { anchors.centerIn: parent; icon: appRow.modelData.icon; font.pixelSize: 15; color: Colors.accentText }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    StyledText { text: appRow.modelData.name }
                                    StyledText { text: appRow.modelData.category; opacity: 0.5; font.pixelSize: Config.fontSize - 4 }
                                }
                            }

                            StyledText {
                                text: appRow.modelData.duration
                                anchors.right: chevron.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                font.family: Config.monoFontFamily
                                opacity: 0.8
                            }

                            MaterialIcon {
                                id: chevron
                                icon: "chevron_right"
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: 0.5
                                rotation: appRow.expanded ? 90 : 0
                                Behavior on rotation { NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expandedApp = appRow.expanded ? "" : appRow.modelData.cls
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 5
                            radius: height / 2
                            color: Colors.surfaceHigh

                            Rectangle {
                                width: parent.width * appRow.modelData.fraction
                                height: parent.height
                                radius: parent.radius
                                color: appRow.appColor
                            }
                        }
                    }

                    // --- Expanded drawer: weekly sparkline + daily limit -----
                    Item {
                        width: parent.width
                        height: appRow.expanded ? drawer.implicitHeight : 0
                        clip: true
                        opacity: appRow.expanded ? 1 : 0

                        Behavior on height { NumberAnimation { duration: Config.animMedium; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                        Column {
                            id: drawer
                            x: 38
                            width: parent.width - 38
                            spacing: 12

                            readonly property var spark: appRow.expanded ? Activity.appSparkline(appRow.modelData.cls) : []
                            readonly property real maxSpark: Math.max(1, ...(drawer.spark.length ? drawer.spark : [0]))

                            Row {
                                width: parent.width
                                height: 32
                                spacing: 4

                                Repeater {
                                    model: drawer.spark

                                    Rectangle {
                                        required property real modelData
                                        required property int index
                                        readonly property bool isToday: index === Activity.highlightedDayIndex

                                        width: (drawer.width - 6 * 4) / 7
                                        anchors.bottom: parent.bottom
                                        height: Math.max(3, 32 * (modelData / drawer.maxSpark))
                                        radius: 2
                                        color: isToday ? appRow.appColor : Colors.surfaceHigh
                                    }
                                }
                            }

                            Row {
                                spacing: 10

                                StyledText {
                                    text: "Daily limit"
                                    opacity: 0.6
                                    font.pixelSize: Config.fontSize - 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Rectangle {
                                    width: 70
                                    height: 30
                                    radius: Colors.radiusSmall
                                    color: Colors.surfaceHigh
                                    anchors.verticalCenter: parent.verticalCenter

                                    TextInput {
                                        id: limitInput
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        verticalAlignment: Text.AlignVCenter
                                        color: Colors.text
                                        font.family: Config.fontFamily
                                        font.pixelSize: Config.fontSize - 1
                                        clip: true
                                        validator: IntValidator { bottom: 0; top: 999 }
                                        // Read directly from Activity (not baked into modelData) so
                                        // saving a limit updates just this field in place instead of
                                        // invalidating selectedApps and destroying this very delegate
                                        // — see appColor above for the same reasoning.
                                        readonly property int savedLimit: Activity.limitMinutesFor(appRow.modelData.cls)
                                        text: savedLimit > 0 ? String(savedLimit) : ""

                                        StyledText {
                                            visible: limitInput.text.length === 0
                                            text: "e.g. 30m"
                                            opacity: 0.4
                                            font.pixelSize: Config.fontSize - 1
                                        }
                                    }
                                }

                                StyledText {
                                    text: "Save"
                                    color: Colors.accent
                                    font.pixelSize: Config.fontSize - 2
                                    anchors.verticalCenter: parent.verticalCenter

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const v = parseInt(limitInput.text);
                                            Activity.setLimitMinutes(appRow.modelData.cls, isNaN(v) ? 0 : v);
                                            savedHint.opacity = 1;
                                            savedHintTimer.restart();
                                        }
                                    }
                                }

                                StyledText {
                                    id: savedHint
                                    text: "Saved"
                                    color: Colors.success
                                    font.pixelSize: Config.fontSize - 2
                                    opacity: 0
                                    anchors.verticalCenter: parent.verticalCenter

                                    Behavior on opacity { NumberAnimation { duration: Config.animFast } }

                                    Timer {
                                        id: savedHintTimer
                                        interval: 1800
                                        onTriggered: savedHint.opacity = 0
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                visible: root.searchQuery.length === 0 && root.filteredApps.length > root.visibleAppCount
                text: root.showAllApps ? "Show less" : "Show all (" + root.filteredApps.length + ")"
                anchors.horizontalCenter: parent.horizontalCenter
                color: Colors.accent
                font.pixelSize: Config.fontSize - 2

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showAllApps = !root.showAllApps
                }
            }
        }

        // --- By category -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10
            visible: root.viewMode === "category"

            StyledText {
                visible: root.categoryGroups.length === 0
                text: "No activity tracked for this day"
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
            }

            Row {
                width: parent.width
                height: 8
                visible: root.categoryGroups.length > 0

                Repeater {
                    model: root.categoryGroups

                    Rectangle {
                        required property var modelData
                        height: parent.height
                        width: root.selectedTotalSeconds > 0 ? parent.width * (modelData.seconds / root.selectedTotalSeconds) : 0
                        color: Activity.categoryColorFor(modelData.name)
                    }
                }
            }

            Repeater {
                model: root.categoryGroups

                Item {
                    id: catRow
                    required property var modelData
                    width: parent.width
                    height: 34

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Rectangle { width: 8; height: 8; radius: 4; color: Activity.categoryColorFor(catRow.modelData.name); anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: catRow.modelData.name; anchors.verticalCenter: parent.verticalCenter }
                        StyledText {
                            text: catRow.modelData.count + (catRow.modelData.count > 1 ? " apps" : " app")
                            opacity: 0.5
                            font.pixelSize: Config.fontSize - 3
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: Activity.fmtDuration(modelData.seconds)
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Config.monoFontFamily
                        opacity: 0.8
                    }
                }
            }
        }
    }
}
