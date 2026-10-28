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
    // A plain card (see IslandNavigation.satellites) brings its own look and
    // sits on the screen background rather than the Island's material.
    readonly property bool plainCard: root.field("card", "") === "plain" && root.expanded
    readonly property real plainScale: Config.fontSize / 13
    property color defaultFillColor: Colors.surface

    padH: root.plainCard ? 24 * root.plainScale : Config.satellitePadH
    padV: root.plainCard ? 24 * root.plainScale : Config.satellitePadV
    plainSurface: root.plainCard
    radiusLimit: root.plainCard ? 16 * root.plainScale : 18
    fillColor: root.plainCard ? Colors.background : root.defaultFillColor

    // A catalogue badgeFile replaces the icon/text badge; its badgeWidth, if
    // any, widens the collapsed badge to fit.
    readonly property string badgeFile: root.field("badgeFile", "")
    badge: root.badgeFile ? Qt.createComponent(root.badgeFile) : activityBadge
    badgeWidth: Math.max(Config.satelliteBadgeSize, root.badgeItem && root.badgeItem.badgeWidth || 0)

    onRight: root.definition ? root.definition.onRight : root.slotOnRight
    label: root.definition ? qsTr(root.definition.label) : ""
    active: !!root.definition && IslandNavigation.shows(root.definition)
    interactive: true
    expanded: root.activityId.length > 0 && IslandNavigation.satelliteOpenFor(root.targetScreen, root.activityId)
    onClicked: IslandNavigation.toggle(root.targetScreen, root.activityId)
    onCloseRequested: IslandNavigation.closeSatellite(root.targetScreen)

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
