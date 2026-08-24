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

    Component {
        id: toggleRow

        Item {
            id: delegate
            required property var modelData
            width: col.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                MaterialIcon { icon: delegate.modelData.icon; font.pixelSize: 16; opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                StyledText { text: delegate.modelData.label; anchors.verticalCenter: parent.verticalCenter }
            }

            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: Config[delegate.modelData.key]
                onToggled: v => Config.setWidgetVisible(delegate.modelData.key, v)
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: 16

        // --- Idle bump ---------------------------------------------------
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

        Column {
            width: parent.width
            spacing: 2

            Repeater { model: root.idleWidgetOptions; delegate: toggleRow }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.4 }

        // --- Widgets ---------------------------------------------------
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

        Column {
            width: parent.width
            spacing: 2

            Repeater { model: root.widgetOptions; delegate: toggleRow }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.4 }

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

            Rectangle {
                width: parent.width
                height: 36
                radius: Colors.radiusSmall
                color: Colors.surfaceHigh

                TextInput {
                    id: weatherInput
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Colors.text
                    font.family: Config.fontFamily
                    font.pixelSize: Config.fontSize
                    clip: true
                    text: root.weatherDraft

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

            Row {
                spacing: 8

                Rectangle {
                    width: weatherApplyText.implicitWidth + 20
                    height: 30
                    radius: Colors.radiusSmall
                    color: Colors.accent

                    StyledText {
                        id: weatherApplyText
                        anchors.centerIn: parent
                        text: "Apply"
                        color: Colors.accentText
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Weather.setLocation(root.weatherDraft)
                    }
                }

                Rectangle {
                    width: weatherClearText.implicitWidth + 20
                    height: 30
                    radius: Colors.radiusSmall
                    color: Colors.surfaceHigh

                    StyledText {
                        id: weatherClearText
                        anchors.centerIn: parent
                        text: "Auto-detect"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.weatherDraft = ""; Weather.setLocation(""); }
                    }
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.7
                font.pixelSize: Config.fontSize - 2
                text: Weather.loading ? "Loading…"
                    : Weather.available ? "Now: " + Math.round(Weather.tempC) + "°C, " + Weather.condition
                        + (Weather.location ? " — " + Weather.location : "")
                    : "No data yet"
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.overlay; opacity: 0.4 }

        // --- Appearance --------------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            StyledText { font.bold: true; text: "Appearance" }

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

            Row {
                spacing: 8

                Rectangle {
                    width: applyText.implicitWidth + 20
                    height: 30
                    radius: Colors.radiusSmall
                    color: Colors.accent

                    StyledText {
                        id: applyText
                        anchors.centerIn: parent
                        text: "Apply"
                        color: Colors.accentText
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.setIslandAppearance(root.draftWidth, root.draftHeight, root.draftGap, root.draftFontSize)
                    }
                }

                Rectangle {
                    width: resetText.implicitWidth + 20
                    height: 30
                    radius: Colors.radiusSmall
                    color: Colors.surfaceHigh

                    StyledText {
                        id: resetText
                        anchors.centerIn: parent
                        text: "Reset"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.resetIslandAppearance();
                            root.draftWidth = Config.idleBumpWidth;
                            root.draftHeight = Config.idleBumpHeight;
                            root.draftGap = Config.islandTopGap;
                            root.draftFontSize = Config.fontSize;
                        }
                    }
                }
            }

            StyledText {
                width: parent.width
                wrapMode: Text.WordWrap
                opacity: 0.6
                font.pixelSize: Config.fontSize - 2
                text: "Applies immediately and persists across restarts. Width/height are the idle bump's size — the island still grows past them when hovered or expanded."
            }
        }
    }
}
