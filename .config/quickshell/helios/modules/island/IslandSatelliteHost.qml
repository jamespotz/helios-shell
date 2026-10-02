import QtQuick
import "../../services"
import "../../components"

IslandSatellite {
    id: root
    required property var definition
    required property string targetScreen
    property bool slotOnRight: false
    readonly property string activityId: root.definition ? root.definition.id : ""
    readonly property bool recordingCard: root.activityId === "recording" && root.expanded
    readonly property real recordingScale: Config.fontSize / 13
    property color defaultFillColor: Colors.surface

    padH: root.recordingCard ? 24 * root.recordingScale : Config.satellitePadH
    padV: root.recordingCard ? 24 * root.recordingScale : Config.satellitePadV
    plainSurface: root.recordingCard
    radiusLimit: root.recordingCard ? 16 * root.recordingScale : 18
    fillColor: root.recordingCard ? (Themes.isDark(Colors.background) ? "#12151f" : "#ffffff") : root.defaultFillColor

    onRight: root.definition ? root.definition.onRight : root.slotOnRight
    label: root.definition ? qsTr(root.definition.label) : ""
    active: !!root.definition && root.definition.active()
    interactive: true
    expanded: root.activityId.length > 0 && IslandNavigation.satelliteOpenFor(root.targetScreen, root.activityId)
    onClicked: IslandNavigation.toggleSatellite(root.targetScreen, root.activityId)
    onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)

    badge: Component {
        Loader {
            sourceComponent: root.activityId === "recording" ? recordingBadge : activityBadge
        }
    }
    Component {
        id: recordingBadge
        Row {
            spacing: 6
            RecordingDot { anchors.verticalCenter: parent.verticalCenter }
            MaterialIcon {
                visible: MicActivity.isSystemMicActive || CameraActivity.isSystemCameraActive
                icon: CameraActivity.isSystemCameraActive ? "videocam" : "mic"
                font.pixelSize: 14
                color: Colors.danger
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
    Component {
        id: activityBadge
        Item {
            implicitWidth: 22
            implicitHeight: 20
            readonly property string value: root.activityId === "meeting" && Calendar.upcomingAlert
                ? qsTr("%1m").arg(Calendar.upcomingMinutesUntil)
                : root.activityId === "tasks" && Tasks.items.length > 1 ? String(Tasks.items.length)
                : root.activityId === "tasks" && Tasks.items.length === 1 && Tasks.items[0].status === "running" && Tasks.items[0].progress >= 0
                    ? Math.round(Math.max(0, Math.min(1, Tasks.items[0].progress)) * 100) + "%" : ""
            MaterialIcon {
                anchors.centerIn: parent
                visible: parent.value.length === 0
                font.pixelSize: 16
                icon: root.activityId === "privacy-status" ? (CameraActivity.isSystemCameraActive ? "videocam" : "mic")
                    : root.activityId === "caffeine" ? "coffee"
                    : root.activityId === "focus-status" ? "center_focus_strong"
                    : root.activityId === "meeting" ? "event"
                    : root.activityId === "tasks" ? (Tasks.items.some(t => t.status === "error") ? "error" : "sync")
                    : Maintenance.rebootRequired || Maintenance.failedUnits.length > 0 ? "error" : "download"
                color: root.activityId === "privacy-status" || (root.activityId === "tasks" && Tasks.items.some(t => t.status === "error"))
                    || (root.activityId === "maintenance" && (Maintenance.rebootRequired || Maintenance.failedUnits.length > 0)) ? Colors.danger
                    : root.activityId === "caffeine" ? Colors.warning : Colors.accent
            }
            StyledText {
                anchors.centerIn: parent
                visible: parent.value.length > 0
                text: parent.value
                font.pixelSize: Config.fontSize - 3
                font.weight: Font.DemiBold
                color: Colors.accent
            }
        }
    }
    expandedContent: Component {
        SatelliteDestinationHost {
            destinationId: root.activityId
            targetScreen: root.targetScreen
            maxContentWidth: Math.max(0, root.parent.width - root.padH * 2)
            maxContentHeight: Math.max(0, root.parent.height - root.anchorItem.y
                - (root.below ? root.parent.height / 2 : 0) - root.padV * 2 - 60)
        }
    }
}
