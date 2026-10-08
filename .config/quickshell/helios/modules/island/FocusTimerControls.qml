import QtQuick
import "../../services"
import "../../components"

Column {
    id: root
    spacing: 8
    property string presetId: ""
    StyledText { text: qsTr("Focus timer"); font.weight: Font.DemiBold }
    StyledText { visible: FocusTimer.active; text: FocusTimer.remainingText + (FocusTimer.state.status === "paused" ? qsTr(" · Paused") : ""); font.pixelSize: Config.fontSize + 4 }
    Column {
        visible: !FocusTimer.active
        width: parent.width
        spacing: 6
        StyledText { text: qsTr("Start with a preset"); color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
        PrimaryButton { width: parent.width; text: qsTr("Timer only"); active: root.presetId === ""; onClicked: root.presetId = "" }
        Repeater {
            model: FocusModes.presets
            PrimaryButton {
                required property var modelData
                width: root.width
                text: modelData.name
                active: root.presetId === modelData.id
                onClicked: root.presetId = modelData.id
            }
        }
        Row {
            width: parent.width
            spacing: 8
            PrimaryButton { width: (parent.width - 8) / 2; text: qsTr("25 minutes"); icon: "timer"; onClicked: FocusTimer.start(25, root.presetId) }
            PrimaryButton { width: (parent.width - 8) / 2; text: qsTr("50 minutes"); icon: "timer"; onClicked: FocusTimer.start(50, root.presetId) }
        }
    }
    Row {
        visible: FocusTimer.active
        width: parent.width
        spacing: 8
        PrimaryButton { width: (parent.width - 8) / 2; text: FocusTimer.state.status === "paused" ? qsTr("Resume") : qsTr("Pause"); onClicked: FocusTimer.state.status === "paused" ? FocusTimer.resume() : FocusTimer.pause() }
        PrimaryButton { width: (parent.width - 8) / 2; text: qsTr("+5 minutes"); onClicked: FocusTimer.extend(5) }
    }
    PrimaryButton { visible: FocusTimer.active; width: parent.width; text: qsTr("Stop timer"); icon: "stop"; onClicked: FocusTimer.stop() }
    StyledText { visible: FocusTimer.error.length > 0; width: parent.width; wrapMode: Text.Wrap; text: FocusTimer.error; color: Colors.danger }
}
