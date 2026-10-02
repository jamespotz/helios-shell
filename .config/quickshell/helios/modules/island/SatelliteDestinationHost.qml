import QtQuick
import "../../services"
import "../../components"

// Expanded contents plus access to activities waiting for the same slot.
Item {
    id: root
    required property string destinationId
    required property string targetScreen
    property real maxContentWidth: Config.islandMaxWidth
    property real maxContentHeight: Config.islandMaxHeight
    property bool otherOpen: false
    readonly property var definition: IslandNavigation.satellites.find(s => s.id === root.destinationId)
    readonly property var others: root.definition
        ? IslandNavigation.satellitesFor(root.targetScreen, root.definition.onRight).filter(s => s.id !== root.destinationId) : []
    implicitWidth: destination.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: root.width
        spacing: 12
        Loader {
            id: destination
            width: parent.width
            sourceComponent: root.destinationId === "recording" ? recording : generic
        }
        HoverRow {
            width: parent.width
            height: 32
            visible: root.others.length > 0
            label: qsTr("Other activity")
            onClicked: root.otherOpen = !root.otherOpen
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                MaterialIcon { icon: root.otherOpen ? "expand_less" : "chevron_right"; font.pixelSize: 16; color: Colors.subtext }
                StyledText { text: qsTr("Other activity (%1)").arg(root.others.length); color: Colors.subtext; font.pixelSize: Config.fontSize - 1 }
            }
        }
        Column {
            id: otherList
            width: parent.width
            visible: root.otherOpen && root.others.length > 0
            spacing: 4
            Repeater {
                model: root.others
                HoverRow {
                    required property var modelData
                    width: otherList.width
                    height: 36
                    label: qsTr(modelData.label)
                    onClicked: {
                        root.otherOpen = false;
                        IslandNavigation.showSatellite(root.targetScreen, modelData.id);
                    }
                    StyledText { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: qsTr(modelData.label) }
                }
            }
        }
    }
    Component {
        id: recording
        RecordingDestination { targetScreen: root.targetScreen }
    }
    Component {
        id: generic
        IslandDestinationHost {
            destinationId: root.destinationId
            targetScreen: root.targetScreen
            maxContentWidth: root.maxContentWidth
            maxContentHeight: Math.max(0, root.maxContentHeight - (root.others.length > 0 ? 44 : 0)
                - (otherList.visible ? otherList.implicitHeight + 12 : 0))
            onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)
        }
    }
}
