import QtQuick
import "../../services"
import "../../components"

IslandSatellite {
    id: root
    required property var definition
    required property string targetScreen
    property bool slotOnRight: false
    readonly property string activityId: root.definition ? root.definition.id : ""
    // A catalogue field that may be a value or a function; see IslandNavigation.satellites.
    function field(name, fallback) {
        const v = root.definition ? root.definition[name] : undefined;
        return v === undefined ? fallback : typeof v === "function" ? v() : v;
    }
    readonly property bool recordingCard: root.activityId === "recording" && root.expanded
    readonly property real recordingScale: Config.fontSize / 13
    property color defaultFillColor: Colors.surface

    padH: root.recordingCard ? 24 * root.recordingScale : Config.satellitePadH
    padV: root.recordingCard ? 24 * root.recordingScale : Config.satellitePadV
    plainSurface: root.recordingCard
    radiusLimit: root.recordingCard ? 16 * root.recordingScale : 18
    fillColor: root.recordingCard ? (Themes.isDark(Colors.background) ? "#12151f" : "#ffffff") : root.defaultFillColor

    badgeWidth: root.activityId === "focus-timer" ? Math.max(Config.satelliteBadgeSize, timerMetrics.width + Config.fontSize + 6 + 20) : Config.satelliteBadgeSize

    onRight: root.definition ? root.definition.onRight : root.slotOnRight
    label: root.definition ? qsTr(root.definition.label) : ""
    active: !!root.definition && root.definition.active()
    interactive: true
    expanded: root.activityId.length > 0 && IslandNavigation.satelliteOpenFor(root.targetScreen, root.activityId)
    onClicked: IslandNavigation.toggle(root.targetScreen, root.activityId)
    onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)

    TextMetrics { id: timerMetrics; text: FocusTimer.remainingText; font.family: Config.fontFamily; font.pixelSize: Config.fontSize - 1; font.weight: Font.DemiBold }
    badge: Component {
        Loader {
            sourceComponent: root.activityId === "recording" ? recordingBadge : root.activityId === "focus-timer" ? timerBadge : activityBadge
        }
    }
    Component {
        id: timerBadge
        Row {
            spacing: 6
            readonly property color timerColor: FocusTimer.state.status === "paused" ? Colors.subtext : Colors.accent
            MaterialIcon {
                icon: FocusTimer.state.kind === "focus" ? "timer" : "coffee"
                font.pixelSize: Config.fontSize
                color: parent.timerColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: FocusTimer.remainingText
                font.pixelSize: Config.fontSize - 1
                font.weight: Font.DemiBold
                color: parent.timerColor
                anchors.verticalCenter: parent.verticalCenter
            }
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
            readonly property string value: root.field("badge", "")
            MaterialIcon {
                anchors.centerIn: parent
                visible: parent.value.length === 0
                font.pixelSize: 16
                icon: root.field("icon", "")
                color: root.field("color", Colors.accent)
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
