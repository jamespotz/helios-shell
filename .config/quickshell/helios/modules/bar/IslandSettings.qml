import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    property string draftFontFamily: Config.fontFamily
    property int draftFontSize: Config.fontSize
    property bool fontPickerOpen: false
    property string fontFilterText: ""

    property int draftWidth: Config.idleBumpWidth
    property int draftHeight: Config.idleBumpHeight
    property int draftGap: Config.islandTopGap
    property int draftWidgetSpacing: Config.idleWidgetSpacing
    property string weatherDraft: Weather.locationOverride

    property int draftContentPadH: Config.islandContentPadH
    property int draftContentPadV: Config.islandContentPadV

    property int draftCollapseDelay: Config.hoverCollapseDelay
    property real draftStiffness: Config.islandSpringStiffness
    property real draftDamping: Config.islandSpringDamping
    property real draftShadowGlowRadius: Config.islandShadowGlowRadius
    property real draftShadowSpread: Config.islandShadowSpread

    property int draftSatBadgeSize: Config.satelliteBadgeSize
    property int draftSatRestGap: Config.satelliteRestGap
    property int draftSatPadH: Config.satellitePadH
    property int draftSatPadV: Config.satellitePadV
    property real draftSatShadowGlowRadius: Config.satelliteShadowGlowRadius
    property real draftSatShadowSpread: Config.satelliteShadowSpread
    property real draftSatStiffness: Config.satelliteSpringStiffness
    property real draftSatDamping: Config.satelliteSpringDamping

    readonly property var idleWidgetOptions: [
        { key: "showIdleMedia", icon: "music_note", label: "Now-playing cover" },
        { key: "showIdleClock", icon: "schedule", label: "Clock" },
        { key: "showIdleWeather", icon: "cloud", label: "Weather" },
        { key: "showIdleWorkspaces", icon: "grid_view", label: "Workspaces" },
        { key: "showIdleActiveWindow", icon: "web_asset", label: "Active window" },
        { key: "showIdleTray", icon: "widgets", label: "Tray icons" },
        { key: "showIdleStatusIndicators", icon: "sensors", label: "Status icons" },
        { key: "showIdleClipboard", icon: "content_paste", label: "Clipboard" }
    ]

    readonly property var widgetOptions: [
        { key: "showWorkspaces", icon: "grid_view", label: "Workspaces" },
        { key: "showActiveWindow", icon: "web_asset", label: "Active window" },
        { key: "showClock", icon: "schedule", label: "Clock" },
        { key: "showWeather", icon: "cloud", label: "Weather" },
        { key: "showTray", icon: "widgets", label: "Tray icons" },
        { key: "showStatusIndicators", icon: "sensors", label: "Status icons" },
        { key: "showClipboard", icon: "content_paste", label: "Clipboard" }
    ]

    implicitWidth: 320
    implicitHeight: col.implicitHeight

    // Grouped-list card — macOS System Settings' rows-in-a-rounded-card look,
    // with a hairline between rows (not between cards, those get plain gap).
    component ToggleRow: Item {
        id: delegate
        required property var modelData
        required property int index
        property int count: 0

        width: parent ? parent.width : 0
        height: 40

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            MaterialIcon { icon: delegate.modelData.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: delegate.modelData.label; anchors.verticalCenter: parent.verticalCenter }
        }

        Toggle {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            checked: Config[delegate.modelData.key]
            onToggled: v => Config.setWidgetVisible(delegate.modelData.key, v)
        }

        Rectangle {
            visible: delegate.index < delegate.count - 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 14
            anchors.bottom: parent.bottom
            height: 1
            color: Colors.overlay
            opacity: 0.15
        }
    }

    component SettingsCard: Rectangle {
        default property alias content: inner.children
        property real contentSpacing: 0

        width: parent ? parent.width : 0
        implicitHeight: inner.implicitHeight
        height: implicitHeight
        radius: Colors.radiusLarge
        color: Colors.surfaceHigh

        Column {
            id: inner
            width: parent.width
            spacing: contentSpacing
        }
    }

    component PillButton: Rectangle {
        id: btn
        property string text: ""
        property bool primary: false
        signal clicked()

        width: label.implicitWidth + 24
        height: 32
        radius: height / 2
        color: primary ? Colors.accent : Colors.surface

        StyledText {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.primary ? Colors.accentText : Colors.text
            font.bold: btn.primary
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.overlay
            opacity: hover.hovered ? 0.2 : 0
        }

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Force any focused LabeledNumberField to commit its pending
                // edit (TextInput.editingFinished fires on focus loss) before
                // reading draft values — otherwise a value typed but not
                // Enter/Tab-confirmed gets silently dropped.
                btn.forceActiveFocus();
                btn.clicked();
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 20

        // Header
        Row {
            spacing: 8
            MaterialIcon { icon: "auto_awesome"; font.pixelSize: 18; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
            StyledText { text: "Helios"; font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2; anchors.verticalCenter: parent.verticalCenter }
        }

        // --- Fonts (global) ----------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Fonts" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Applies everywhere in the shell. Icon and monospace fonts are unaffected."
                }
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText { opacity: 0.7; font.pixelSize: Config.fontSize - 2; text: "Font family" }

                        Rectangle {
                            id: fontFamilyButton
                            width: parent.width
                            height: 36
                            radius: root.fontPickerOpen ? Colors.radiusLarge : height / 2
                            color: Colors.surface

                            StyledText {
                                text: root.draftFontFamily
                                font.family: root.draftFontFamily
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.right: fontPickerIcon.left
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                            }

                            MaterialIcon {
                                id: fontPickerIcon
                                icon: root.fontPickerOpen ? "expand_less" : "expand_more"
                                font.pixelSize: 16
                                opacity: 0.6
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.fontPickerOpen = !root.fontPickerOpen;
                                    root.fontFilterText = "";
                                }
                            }
                        }

                        // Wrapped so ScrollIndicator (anchors to its target's
                        // edges) is a sibling of the Flickable rather than a
                        // child inside it — see NotifyCard.qml's identical
                        // reasoning.
                        Item {
                            width: parent.width
                            visible: root.fontPickerOpen
                            height: visible ? 262 : 0
                            clip: true

                            Rectangle {
                                anchors.fill: parent
                                radius: Colors.radiusLarge
                                color: Colors.surface

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    SearchField {
                                        width: parent.width
                                        height: 36
                                        inputPixelSize: Config.fontSize - 2
                                        placeholder: "Filter fonts…"
                                        text: root.fontFilterText
                                        onTextChanged: root.fontFilterText = text
                                    }

                                    ListView {
                                        id: fontList
                                        width: parent.width
                                        height: parent.height - 40
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        model: {
                                            const filter = root.fontFilterText.toLowerCase();
                                            return filter.length === 0
                                                ? Qt.fontFamilies()
                                                : Qt.fontFamilies().filter(f => f.toLowerCase().includes(filter));
                                        }

                                        delegate: Rectangle {
                                            id: fontRow
                                            required property string modelData

                                            width: fontList.width
                                            height: 32
                                            radius: Colors.radiusSmall
                                            color: fontRowHover.hovered ? Colors.surfaceHigh : "transparent"

                                            StyledText {
                                                text: fontRow.modelData
                                                font.family: fontRow.modelData
                                                color: fontRow.modelData === root.draftFontFamily ? Colors.accent : Colors.text
                                                anchors.left: parent.left
                                                anchors.leftMargin: 10
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                elide: Text.ElideRight
                                            }

                                            HoverHandler { id: fontRowHover }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    root.draftFontFamily = fontRow.modelData;
                                                    root.fontPickerOpen = false;
                                                }
                                            }
                                        }
                                    }
                                }

                                ScrollIndicator { target: fontList }
                            }
                        }
                    }

                    LabeledNumberField {
                        label: "Font size"
                        value: root.draftFontSize
                        minValue: 9
                        maxValue: 22
                        onValueEdited: v => root.draftFontSize = v
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setFont(root.draftFontFamily, root.draftFontSize)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetFont();
                            root.draftFontFamily = Config.fontFamily;
                            root.draftFontSize = Config.fontSize;
                        }
                    }
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }
        }

        // --- Idle ----------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Idle" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Choose what shows in the small collapsed pill."
                }
            }

            SettingsCard {
                Repeater {
                    model: root.idleWidgetOptions
                    ToggleRow { count: root.idleWidgetOptions.length }
                }
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    LabeledNumberField {
                        label: "Width"
                        value: root.draftWidth
                        minValue: 80
                        maxValue: 400
                        onValueEdited: v => root.draftWidth = v
                    }
                    LabeledNumberField {
                        label: "Height"
                        value: root.draftHeight
                        minValue: 18
                        maxValue: 60
                        onValueEdited: v => root.draftHeight = v
                    }
                    LabeledNumberField {
                        label: "Top gap"
                        value: root.draftGap
                        minValue: 0
                        maxValue: 40
                        onValueEdited: v => root.draftGap = v
                    }
                    LabeledNumberField {
                        label: "Widget spacing"
                        value: root.draftWidgetSpacing
                        minValue: 0
                        maxValue: 40
                        onValueEdited: v => root.draftWidgetSpacing = v
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setIslandAppearance(root.draftWidth, root.draftHeight, root.draftGap, root.draftWidgetSpacing)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetIslandAppearance();
                            root.draftWidth = Config.idleBumpWidth;
                            root.draftHeight = Config.idleBumpHeight;
                            root.draftGap = Config.islandTopGap;
                            root.draftWidgetSpacing = Config.idleWidgetSpacing;
                        }
                    }
                }

                StyledText {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Applies immediately and persists across restarts. Width/height are the idle bump's size — the island still grows past them when hovered or expanded."
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }
        }

        // --- Expanded --------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Expanded" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Choose what shows and how much padding it gets when the island expands."
                }
            }

            SettingsCard {
                Repeater {
                    model: root.widgetOptions
                    ToggleRow { count: root.widgetOptions.length }
                }
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    LabeledNumberField {
                        label: "Content padding (H)"
                        value: root.draftContentPadH
                        minValue: 0
                        maxValue: 60
                        onValueEdited: v => root.draftContentPadH = v
                    }
                    LabeledNumberField {
                        label: "Content padding (V)"
                        value: root.draftContentPadV
                        minValue: 0
                        maxValue: 40
                        onValueEdited: v => root.draftContentPadV = v
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setExpandedAppearance(root.draftContentPadH, root.draftContentPadV)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetExpandedAppearance();
                            root.draftContentPadH = Config.islandContentPadH;
                            root.draftContentPadV = Config.islandContentPadV;
                        }
                    }
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }
        }

        // --- Clock format ----------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Clock format" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Applies to every clock in the shell, including the lock screen."
                }
            }

            SettingsCard {
                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: "schedule"; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "24-hour time"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Config.use24HourClock
                        onToggled: v => Config.setWidgetVisible("use24HourClock", v)
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Colors.overlay
                        opacity: 0.15
                    }
                }

                Item {
                    width: parent.width
                    height: 40
                    enabled: !Config.use24HourClock
                    opacity: enabled ? 1 : 0.4

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: "text_fields"; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Uppercase AM/PM"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Config.clockAmPmUppercase
                        onToggled: v => Config.setWidgetVisible("clockAmPmUppercase", v)
                    }
                }
            }
        }

        // --- Weather -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            StyledText { font.bold: true; text: "Weather location" }
            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
                text: "City name, or \"lat,long\". Leave empty to auto-detect from this machine's IP. Also used for Night Light's sunset-to-sunrise schedule."
            }

            SettingsCard {
                contentSpacing: 12
                Item {
                    width: parent.width
                    height: 1
                } // top padding

                Item {
                    width: parent.width - 28
                    height: 36
                    anchors.left: parent.left
                    anchors.leftMargin: 14

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Colors.surface

                        TextInput {
                            id: weatherInput
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            color: Colors.text
                            font.family: Config.fontFamily
                            font.pixelSize: Config.fontSize
                            clip: true
                            text: root.weatherDraft
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: root.weatherDraft = text
                            Keys.onReturnPressed: Weather.setLocation(root.weatherDraft)

                            StyledText {
                                visible: weatherInput.text.length === 0
                                text: "e.g. Tokyo or 35.68,139.69"
                                opacity: 0.5
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton { text: "Apply"; primary: true; onClicked: Weather.setLocation(root.weatherDraft) }
                    PillButton { text: "Auto-detect"; onClicked: { root.weatherDraft = ""; Weather.setLocation(""); } }
                }

                StyledText {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    wrapMode: Text.WordWrap
                    opacity: 0.7
                    font.pixelSize: Config.fontSize - 2
                    text: Weather.loading ? "Loading…"
                        : Weather.available ? "Now: " + Math.round(Weather.tempC) + "°C, " + Weather.condition
                            + (Weather.location ? " — " + Weather.location : "")
                        : "No data yet"
                }

                Item {
                    width: parent.width
                    height: 13
                } // bottom padding
            }
        }

        // --- Behavior (main island: idle + expanded) ------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Behavior" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "How the island reacts to hover, its morph animation, and its shadow. Shared by idle and expanded — they're the same shape."
                }
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        MaterialIcon { icon: "blur_on"; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        StyledText { text: "Liquid glass"; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Toggle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Bridge.liquidGlassEnabled
                        onToggled: v => Bridge.liquidGlassEnabled = v
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Colors.overlay
                        opacity: 0.15
                    }
                }

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    LabeledNumberField {
                        label: "Collapse delay"
                        value: root.draftCollapseDelay
                        minValue: 0
                        maxValue: 2000
                        onValueEdited: v => root.draftCollapseDelay = v
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Morph stiffness — " + root.draftStiffness.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftStiffness
                            maxValue: 12
                            onMoved: v => root.draftStiffness = Math.round(v * 10) / 10
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Morph damping — " + root.draftDamping.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftDamping
                            maxValue: 2
                            onMoved: v => root.draftDamping = Math.round(v * 10) / 10
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Shadow glow radius — " + root.draftShadowGlowRadius.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftShadowGlowRadius
                            maxValue: 32
                            onMoved: v => root.draftShadowGlowRadius = Math.round(v * 10) / 10
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Shadow spread — " + root.draftShadowSpread.toFixed(2)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftShadowSpread
                            maxValue: 0.5
                            onMoved: v => root.draftShadowSpread = Math.round(v * 100) / 100
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setIslandBehavior(root.draftCollapseDelay, root.draftStiffness, root.draftDamping, root.draftShadowGlowRadius, root.draftShadowSpread)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetIslandBehavior();
                            root.draftCollapseDelay = Config.hoverCollapseDelay;
                            root.draftStiffness = Config.islandSpringStiffness;
                            root.draftDamping = Config.islandSpringDamping;
                            root.draftShadowGlowRadius = Config.islandShadowGlowRadius;
                            root.draftShadowSpread = Config.islandShadowSpread;
                        }
                    }
                }

                StyledText {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Higher stiffness snaps open faster; damping near 1 stays smooth, lower values overshoot before settling. Liquid glass applies immediately."
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }
        }

        // --- Satellite -------------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Satellite" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "The small badges next to the island (recording, maintenance) — sizing, shadow, and their own independent motion."
                }
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    LabeledNumberField {
                        label: "Badge size"
                        value: root.draftSatBadgeSize
                        minValue: 20
                        maxValue: 60
                        onValueEdited: v => root.draftSatBadgeSize = v
                    }
                    LabeledNumberField {
                        label: "Rest gap"
                        value: root.draftSatRestGap
                        minValue: 0
                        maxValue: 24
                        onValueEdited: v => root.draftSatRestGap = v
                    }
                    LabeledNumberField {
                        label: "Padding (H)"
                        value: root.draftSatPadH
                        minValue: 0
                        maxValue: 40
                        onValueEdited: v => root.draftSatPadH = v
                    }
                    LabeledNumberField {
                        label: "Padding (V)"
                        value: root.draftSatPadV
                        minValue: 0
                        maxValue: 40
                        onValueEdited: v => root.draftSatPadV = v
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Shadow glow radius — " + root.draftSatShadowGlowRadius.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftSatShadowGlowRadius
                            maxValue: 20
                            onMoved: v => root.draftSatShadowGlowRadius = Math.round(v * 10) / 10
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Shadow spread — " + root.draftSatShadowSpread.toFixed(2)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftSatShadowSpread
                            maxValue: 0.5
                            onMoved: v => root.draftSatShadowSpread = Math.round(v * 100) / 100
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setSatelliteAppearance(root.draftSatBadgeSize, root.draftSatRestGap, root.draftSatPadH, root.draftSatPadV, root.draftSatShadowGlowRadius, root.draftSatShadowSpread)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetSatelliteAppearance();
                            root.draftSatBadgeSize = Config.satelliteBadgeSize;
                            root.draftSatRestGap = Config.satelliteRestGap;
                            root.draftSatPadH = Config.satellitePadH;
                            root.draftSatPadV = Config.satellitePadV;
                            root.draftSatShadowGlowRadius = Config.satelliteShadowGlowRadius;
                            root.draftSatShadowSpread = Config.satelliteShadowSpread;
                        }
                    }
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }

            SettingsCard {
                contentSpacing: 12
                Item { width: parent.width; height: 1 } // top padding

                Column {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 10

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Motion stiffness — " + root.draftSatStiffness.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftSatStiffness
                            maxValue: 12
                            onMoved: v => root.draftSatStiffness = Math.round(v * 10) / 10
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 4

                        StyledText {
                            opacity: 0.7
                            font.pixelSize: Config.fontSize - 2
                            text: "Motion damping — " + root.draftSatDamping.toFixed(1)
                        }
                        Slider {
                            width: parent.width
                            value: root.draftSatDamping
                            maxValue: 2
                            onMoved: v => root.draftSatDamping = Math.round(v * 10) / 10
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    spacing: 8

                    PillButton {
                        text: "Apply"
                        primary: true
                        onClicked: Config.setSatelliteBehavior(root.draftSatStiffness, root.draftSatDamping)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetSatelliteBehavior();
                            root.draftSatStiffness = Config.satelliteSpringStiffness;
                            root.draftSatDamping = Config.satelliteSpringDamping;
                        }
                    }
                }

                StyledText {
                    width: parent.width - 28
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Independent from the main island's morph — badges can feel snappier or looser without affecting idle/expanded."
                }

                Item { width: parent.width; height: 13 } // bottom padding
            }
        }
    }
}
