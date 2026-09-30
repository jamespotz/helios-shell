import QtQuick
import "../../services"
import "../../components"

IslandSatellite {
    id: root
    required property var definition
    required property string targetScreen

    onRight: root.definition.onRight
    label: root.definition.label
    active: root.definition.active()
    interactive: true
    expanded: IslandNavigation.satelliteOpenFor(root.targetScreen, root.definition.id)
    onClicked: IslandNavigation.toggleSatellite(root.targetScreen, root.definition.id)
    onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)

    badge: Component {
        Loader {
            sourceComponent: root.definition.id === "recording" ? recordingBadge : maintenanceBadge
        }
    }
    Component {
        id: recordingBadge
        RecordingDot {}
    }
    Component {
        id: maintenanceBadge
        MaterialIcon {
            width: font.pixelSize
            height: font.pixelSize
            font.pixelSize: 16
            icon: Maintenance.rebootRequired || Maintenance.failedUnits.length > 0 ? "error" : "download"
            color: Maintenance.rebootRequired || Maintenance.failedUnits.length > 0 ? Colors.danger : Colors.accent
        }
    }
    expandedContent: Component {
        PanelWrapper {
            destinationId: root.definition.id
            targetScreen: root.targetScreen
            maxContentWidth: Math.max(0, root.parent.width - root.padH * 2)
            maxContentHeight: Math.max(0, root.parent.height - root.anchorItem.y
                - (root.below ? root.parent.height / 2 : 0) - root.padV * 2 - 60)
            onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)
        }
    }
}
