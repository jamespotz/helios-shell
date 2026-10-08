import QtQuick
import "../../services"
import "../../components"

Item {
    implicitWidth: 280
    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 12
        Loader {
            width: parent.width
            active: FocusTimer.active
            visible: active
            sourceComponent: Component { FocusTimerControls { width: parent.width } }
        }
        StyledText { text: qsTr("Focus mode"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        Repeater {
            model: FocusModes.presets
            PrimaryButton {
                required property var modelData
                width: column.width
                text: modelData.name
                icon: modelData.icon || "center_focus_strong"
                active: FocusModes.activeId === modelData.id
                onClicked: FocusModes.toggle(modelData)
            }
        }
        PrimaryButton {
            width: parent.width
            text: qsTr("End focus mode")
            icon: "close"
            enabled: FocusModes.activeId.length > 0
            onClicked: FocusModes.deactivate()
        }
    }
}
