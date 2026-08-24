import QtQuick
import "../../services"
import "../../components"

Item {
    id: root

    property int draftWidth: Config.idleBumpWidth
    property int draftHeight: Config.idleBumpHeight
    property int draftGap: Config.islandTopGap
    property int draftFontSize: Config.fontSize
    property string weatherDraft: Weather.locationOverride

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
            onClicked: btn.clicked()
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 20

        // --- Idle bump ---------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Idle bump" }
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
        }

        // --- Widgets ---------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Column {
                width: parent.width
                spacing: 2

                StyledText { font.bold: true; text: "Widgets" }
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    opacity: 0.6
                    font.pixelSize: Config.fontSize - 2
                    text: "Choose what shows in the expanded island."
                }
            }

            SettingsCard {
                Repeater {
                    model: root.widgetOptions
                    ToggleRow { count: root.widgetOptions.length }
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
                text: "City name, or \"lat,long\". Leave empty to auto-detect from this machine's IP."
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

        // --- Appearance --------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            StyledText { font.bold: true; text: "Appearance" }

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
                        onClicked: Config.setIslandAppearance(root.draftWidth, root.draftHeight, root.draftGap, root.draftFontSize)
                    }
                    PillButton {
                        text: "Reset"
                        onClicked: {
                            Config.resetIslandAppearance();
                            root.draftWidth = Config.idleBumpWidth;
                            root.draftHeight = Config.idleBumpHeight;
                            root.draftGap = Config.islandTopGap;
                            root.draftFontSize = Config.fontSize;
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
    }
}
