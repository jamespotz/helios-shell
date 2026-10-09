import QtQuick
import "../../services"
import "../../components"

Column {
    id: root
    spacing: 16
    property string presetId: ""
    property int customFocusMinutes: 25
    property int customBreakMinutes: Config.shortBreakMinutes
    readonly property bool isBreak: FocusTimer.state.kind !== "focus"

    Row {
        spacing: 8
        MaterialIcon { icon: root.isBreak && FocusTimer.active ? "coffee" : "timer"; color: Colors.accent; anchors.verticalCenter: parent.verticalCenter }
        StyledText { text: FocusTimer.active && root.isBreak ? qsTr("Break") : qsTr("Focus timer"); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }

    Column {
        visible: !FocusTimer.active
        width: parent.width
        spacing: 12
        Row {
            width: parent.width
            spacing: 8
            Repeater {
                model: [25, 50, 90]
                Chip {
                    required property int modelData
                    width: (parent.width - 16) / 3
                    text: qsTr("%1 minutes").arg(modelData)
                    active: root.customFocusMinutes === modelData && root.customBreakMinutes === FocusTimer.breakMinutes(modelData === 25 ? "short" : modelData === 50 ? "long" : "extended")
                    onClicked: {
                        root.customFocusMinutes = modelData;
                        root.customBreakMinutes = FocusTimer.breakMinutes(modelData === 25 ? "short" : modelData === 50 ? "long" : "extended");
                    }
                }
            }
        }
        Row {
            width: parent.width
            spacing: 12
            Column {
                width: (parent.width - 12) / 2
                spacing: 6
                StyledText { text: qsTr("Focus · minutes"); color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
                LabeledNumberField { id: focusInput; objectName: "customFocusMinutes"; label: qsTr("Focus minutes"); showLabel: false; inputWidth: parent.width; value: root.customFocusMinutes; minValue: 1; maxValue: 180; onValueEdited: value => root.customFocusMinutes = value }
            }
            Column {
                width: (parent.width - 12) / 2
                spacing: 6
                StyledText { text: qsTr("Break · minutes"); color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
                LabeledNumberField { id: breakInput; objectName: "customBreakMinutes"; label: qsTr("Break minutes"); showLabel: false; inputWidth: parent.width; value: root.customBreakMinutes; minValue: 1; maxValue: 60; onValueEdited: value => root.customBreakMinutes = value }
            }
        }
        Flow {
            width: parent.width
            spacing: 6
            visible: FocusModes.presets.length > 0
            Chip { text: qsTr("Timer only"); active: root.presetId === ""; onClicked: root.presetId = "" }
            Repeater {
                model: FocusModes.presets
                Chip { required property var modelData; text: modelData.name; active: root.presetId === modelData.id; onClicked: root.presetId = modelData.id }
            }
        }
        PrimaryButton { width: parent.width; text: qsTr("Start focus"); enabled: focusInput.acceptableInput && breakInput.acceptableInput; icon: "play_arrow"; onClicked: FocusTimer.startCustom(root.customFocusMinutes, root.customBreakMinutes, root.presetId) }
    }

    Column {
        visible: FocusTimer.active
        width: parent.width
        spacing: 12
        StyledText { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: FocusTimer.remainingText; font.pixelSize: Config.fontSize * 3; font.weight: Font.DemiBold }
        StyledText { visible: FocusTimer.state.status === "paused"; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: qsTr("Paused"); color: Colors.subtext }
        Row {
            width: parent.width
            spacing: 8
            PrimaryButton { width: (parent.width - 8) / 2; text: FocusTimer.state.status === "paused" ? qsTr("Resume") : qsTr("Pause"); icon: FocusTimer.state.status === "paused" ? "play_arrow" : "pause"; onClicked: FocusTimer.state.status === "paused" ? FocusTimer.resume() : FocusTimer.pause() }
            PrimaryButton { width: (parent.width - 8) / 2; text: qsTr("+5 minutes"); onClicked: FocusTimer.extend(5) }
        }
        Chip { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Stop timer"); onClicked: FocusTimer.stop() }
    }
    StyledText { visible: FocusTimer.error.length > 0; width: parent.width; wrapMode: Text.Wrap; text: FocusTimer.error; color: Colors.danger }
}
