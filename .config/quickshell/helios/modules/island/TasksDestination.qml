import QtQuick
import "../../services"
import "../../components"

Item {
    implicitWidth: 300
    implicitHeight: column.implicitHeight
    Column {
        id: column
        width: parent.width
        spacing: 12
        StyledText { text: qsTr("Background tasks"); font.weight: Font.DemiBold; font.pixelSize: Config.fontSize + 2 }
        StyledText { visible: Tasks.items.length === 0; text: qsTr("No active tasks"); color: Colors.subtext }
        TaskCard { width: parent.width; visible: Tasks.items.length > 0 }
        Repeater {
            model: Tasks.items.filter(t => t.status !== "running")
            PrimaryButton {
                required property var modelData
                width: column.width
                text: qsTr("Dismiss %1").arg(modelData.label)
                icon: "close"
                onClicked: Tasks.remove(modelData.id)
            }
        }
    }
}
