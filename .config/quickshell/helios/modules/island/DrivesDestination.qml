import QtQuick
import "../../services"
import "../../components"

Item {
    id: root
    implicitWidth: 380
    implicitHeight: content.implicitHeight
    function sizeText(bytes) {
        return bytes >= 1000000000 ? qsTr("%1 GB").arg((bytes / 1000000000).toFixed(1)) : qsTr("%1 MB").arg((bytes / 1000000).toFixed(1));
    }
    Column {
        id: content
        width: parent.width
        spacing: 12
        Row {
            width: parent.width
            StyledText { text: qsTr("Removable drives"); width: parent.width - refreshButton.width; anchors.verticalCenter: parent.verticalCenter; font.weight: Font.DemiBold }
            IconButton { id: refreshButton; icon: "refresh"; label: qsTr("Refresh drives"); enabled: !RemovableDrives.busy; onClicked: RemovableDrives.refresh() }
        }
        StyledText { visible: RemovableDrives.busy; text: qsTr("Working…"); color: Colors.subtext }
        StyledText { visible: RemovableDrives.error.length > 0; width: parent.width; text: RemovableDrives.error; color: Colors.danger; wrapMode: Text.Wrap }
        StyledText { visible: RemovableDrives.drives.length === 0; text: qsTr("No removable drives connected"); color: Colors.subtext }
        Repeater {
            model: RemovableDrives.drives
            Column {
                id: drive
                required property var modelData
                width: content.width
                spacing: 8
                StyledText { width: parent.width; text: drive.modelData.label + " · " + root.sizeText(drive.modelData.sizeBytes); wrapMode: Text.Wrap; font.weight: Font.DemiBold }
                Repeater {
                    model: drive.modelData.partitions
                    Column {
                        id: partition
                        required property var modelData
                        width: drive.width
                        spacing: 6
                        readonly property bool mounted: modelData.mountPoints.length > 0
                        StyledText { width: parent.width; text: partition.modelData.label + " · " + root.sizeText(partition.modelData.sizeBytes); wrapMode: Text.Wrap }
                        StyledText { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: Config.fontSize - 1; color: Colors.subtext; text: !partition.modelData.supported ? qsTr("Unsupported filesystem") : partition.mounted ? partition.modelData.mountPoints.join("\n") : qsTr("Not mounted") }
                        Row {
                            width: parent.width
                            spacing: 8
                            visible: partition.modelData.supported
                            PrimaryButton { width: partition.mounted ? (parent.width - 8) / 2 : parent.width; text: partition.mounted ? qsTr("Unmount") : qsTr("Mount"); enabled: !RemovableDrives.busy; onClicked: partition.mounted ? RemovableDrives.unmount(partition.modelData.path) : RemovableDrives.mount(partition.modelData.path) }
                            PrimaryButton { width: (parent.width - 8) / 2; visible: partition.mounted; text: qsTr("Open"); icon: "folder_open"; enabled: !RemovableDrives.busy; onClicked: RemovableDrives.open(partition.modelData.path) }
                        }
                    }
                }
                PrimaryButton { width: parent.width; text: qsTr("Safe eject"); icon: "eject"; enabled: !RemovableDrives.busy; onClicked: RemovableDrives.eject(drive.modelData.path) }
            }
        }
    }
}
