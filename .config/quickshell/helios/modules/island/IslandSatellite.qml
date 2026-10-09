import QtQuick
import "../../services"
import "../../components"

// Satellites emerge from inside the Island, stretch as they separate, and
// settle beside it. Destination sizing uses bounded, interruptible transitions.
FocusScope {
    id: root

    // hitArea never animates its own width/height (see Island.qml's comment on
    // hitArea), so positioning off its edges directly would drag this
    // satellite along in the same instant jump. Animate the anchor edge instead
    // of chasing the satellite's animated width with a second spring.
    required property Item anchorItem
    property bool onRight: false
    property real restGap: Config.satelliteRestGap

    property bool active: false
    property bool expanded: false
    property bool interactive: false
    property string label: ""
    readonly property bool shown: root.active || root.expanded

    property int badgeSize: Config.satelliteBadgeSize
    property real badgeWidth: root.badgeSize
    property real padH: Config.satellitePadH
    property real padV: Config.satellitePadV

    property color fillColor: Colors.surface
    property bool plainSurface: false
    property real radiusLimit: 18
    property bool shadowEnabled: true
    // Small enough that the blur doesn't reach past restGap into the
    // island's own shadow — keeps a visible shadow without the two merging
    // into a bridge across the gap. User-tunable from Settings >
    // Island.
    property real shadowGlowRadius: Config.satelliteShadowGlowRadius
    property real shadowSpread: Config.satelliteShadowSpread

    property Component badge
    property Component expandedContent

    signal clicked()
    signal closeRequested()

    property real gap: 0
    property real entranceProgress: 1
    // The Island covers the emerging blob until it has separated.
    z: root.entranceProgress < 1 ? -1 : 0

    // Same escape-to-close as the main island's hitArea (Island.qml) — focus
    // has to sit here, the shallowest ancestor of expandedContent, so keys
    // typed into a nested field (e.g. a SearchField) still bubble up to it.
    focus: root.expanded
    Keys.onEscapePressed: root.closeRequested()
    onExpandedChanged: { if (root.expanded) root.forceActiveFocus(); }
    TapHandler {
        onPressedChanged: {
            if (pressed && root.expanded && !root.activeFocus) root.forceActiveFocus();
        }
    }

    // If the expanded destination cannot fit beside the Island, place it
    // below. Keep every painted and interactive pixel inside the surface.
    readonly property real sideSpace: root.onRight
        ? parent.width - anchorItem.x - anchorItem.width - root.restGap
        : anchorItem.x - root.restGap
    readonly property bool below: root.expanded && root._expandedWidth > root.sideSpace
    readonly property real desiredAnchorX: root.below
        ? anchorItem.x + anchorItem.width / 2
        : root.onRight ? anchorItem.x + anchorItem.width : anchorItem.x
    property real animatedAnchorX: root.desiredAnchorX
    // Size and position share the same edge, so closing keeps a steady gap.
    // Clamp against the current Island bounds while its anchor spring catches up.
    readonly property real separatedX: root.below ? root.animatedAnchorX - root.width / 2
        : root.onRight ? Math.max(root.animatedAnchorX, anchorItem.x + anchorItem.width) + gap
        : Math.min(root.animatedAnchorX, anchorItem.x) - root.width - gap
    readonly property real emergenceX: anchorItem.x
        + (root.onRight ? anchorItem.width - root.badgeWidth : 0)
        + (root.badgeWidth - root.width) / 2
    readonly property real emergenceY: anchorItem.y + Math.max(0, (anchorItem.height - root.badgeSize) / 2)
    readonly property real restingY: root.below ? anchorItem.y + anchorItem.height + root.restGap : anchorItem.y
    x: Math.max(0, Math.min(root.emergenceX + (root.separatedX - root.emergenceX) * root.entranceProgress,
        parent.width - root.width))
    y: root.emergenceY + (root.restingY - root.emergenceY) * root.entranceProgress
    Behavior on animatedAnchorX {
        enabled: !Config.reducedMotion
        SpringAnimation { spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }

    readonly property real _expandedWidth: expandedLoader.item ? expandedLoader.item.implicitWidth + root.padH * 2 : root.badgeWidth
    readonly property real _expandedHeight: expandedLoader.item ? expandedLoader.item.implicitHeight + root.padV * 2 : root.badgeSize

    width: root.expanded ? Math.min(root._expandedWidth, Config.islandMaxWidth, parent.width) : root.badgeWidth
    height: root.expanded ? Math.max(root.badgeSize, Math.min(root._expandedHeight, Config.islandMaxHeight, parent.height - root.y)) : root.badgeSize
    Behavior on width {
        enabled: !Config.reducedMotion
        NumberAnimation {
            duration: root.expanded ? Config.animSlow : Config.animFast
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        enabled: !Config.reducedMotion
        NumberAnimation {
            duration: root.expanded ? Config.animSlow : Config.animFast
            easing.type: Easing.OutCubic
        }
    }

    opacity: root.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        enabled: !Config.reducedMotion
        NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
    }

    transform: Scale {
        id: liquidScale
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: 1.0
        yScale: 1.0
    }

    function syncEntrance(animate) {
        liquidSlideIn.stop();
        root.gap = root.shown ? root.restGap : 0;
        root.entranceProgress = 1;
        liquidScale.xScale = 1;
        liquidScale.yScale = 1;
        if (root.shown && animate && !Config.reducedMotion) {
            root.entranceProgress = 0;
            liquidScale.xScale = 0.4;
            liquidScale.yScale = 0.7;
            liquidSlideIn.start();
        }
    }
    Component.onCompleted: root.syncEntrance(false)
    onShownChanged: root.syncEntrance(true)
    onRestGapChanged: root.syncEntrance(false)
    Connections {
        target: Config
        function onReducedMotionChanged() { root.syncEntrance(false); }
    }

    ParallelAnimation {
        id: liquidSlideIn
        NumberAnimation { target: root; property: "entranceProgress"; to: 1; duration: Config.animFast + Config.animSlow; easing.type: Easing.OutCubic }
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation { target: liquidScale; property: "xScale"; to: 1.32; duration: Config.animFast; easing.type: Easing.OutCubic }
                NumberAnimation { target: liquidScale; property: "yScale"; to: 0.76; duration: Config.animFast; easing.type: Easing.OutCubic }
            }
            ParallelAnimation {
                NumberAnimation { target: liquidScale; property: "xScale"; to: 1; duration: Config.animSlow; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
                NumberAnimation { target: liquidScale; property: "yScale"; to: 1; duration: Config.animSlow; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
            }
        }
    }

    IslandShape {
        id: islandShape
        anchors.fill: parent
        visible: !root.plainSurface
        radiusLimit: root.radiusLimit
        borderEnabled: Config.satelliteBorder
        borderWidth: Config.satelliteBorderWidth
        fillColor: root.fillColor
        shadowEnabled: root.shadowEnabled
        shadowGlowRadius: root.shadowGlowRadius
        shadowSpread: root.shadowSpread
    }

    Rectangle {
        anchors.fill: parent
        visible: root.plainSurface
        color: root.fillColor
        radius: islandShape.cornerRadius
        antialiasing: true
    }

    // Clip badge and destination to the same rounded shape during the morph.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: islandShape.cornerRadius
        clip: true

        Loader {
            id: badgeLoader
            anchors.centerIn: parent
            active: !root.expanded
            sourceComponent: root.badge
            opacity: root.expanded ? 0 : 1
            Behavior on opacity { enabled: !Config.reducedMotion; NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic } }
        }

        // Closed satellites must not instantiate destinations with background work.
        Loader {
            id: expandedLoader
            anchors.top: parent.top
            anchors.topMargin: root.padV
            anchors.left: parent.left
            anchors.leftMargin: root.padH
            width: Math.max(0, root.width - root.padH * 2)
            active: root.expanded && !!root.expandedContent
            enabled: root.expanded
            sourceComponent: root.expandedContent
            opacity: root.expanded && expandedLoader.item ? 1 : 0
        }
    }

    IconButton {
        anchors.fill: parent
        visible: root.interactive && !root.expanded && root.shown
        enabled: visible && root.enabled
        label: root.label
        onClicked: root.clicked()
    }
}
