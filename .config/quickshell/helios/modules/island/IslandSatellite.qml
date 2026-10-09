import QtQuick
import "../../services"
import "../../components"

// Satellites emerge from the Island and retract along the same path.
// Geometry springs retarget from the current position and velocity.
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

    readonly property real gap: root.shown ? root.restGap : 0
    property real entranceProgress: root.shown ? 1 : 0
    Behavior on entranceProgress {
        enabled: !Config.reducedMotion
        Spring { id: entranceSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }
    // The Island occludes the satellite along both directions of travel.
    z: root.entranceProgress < 0.999 ? -1 : 0

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
    property real belowProgress: root.below ? 1 : 0
    Behavior on belowProgress {
        enabled: !Config.reducedMotion
        Spring { id: placementSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }
    readonly property real desiredAnchorX: root.onRight ? anchorItem.x + anchorItem.width : anchorItem.x
    property real animatedAnchorX: root.desiredAnchorX
    // Size and position share the same edge, so closing keeps a steady gap.
    // Clamp against the current Island bounds while its anchor spring catches up.
    readonly property real sideX: root.onRight
        ? Math.max(root.animatedAnchorX, anchorItem.x + anchorItem.width) + root.restGap
        : Math.min(root.animatedAnchorX, anchorItem.x) - root.width - root.restGap
    readonly property real belowX: root.animatedAnchorX
        + (root.onRight ? -1 : 1) * anchorItem.width / 2 - root.width / 2
    readonly property real separatedX: root.sideX + (root.belowX - root.sideX) * root.belowProgress
    readonly property real emergenceX: anchorItem.x
        + (root.onRight ? anchorItem.width - root.badgeWidth : 0)
        + (root.badgeWidth - root.width) / 2
    readonly property real emergenceY: anchorItem.y + Math.max(0, (anchorItem.height - root.badgeSize) / 2)
    readonly property real restingY: root.below ? anchorItem.y + anchorItem.height + root.restGap : anchorItem.y
    x: Math.max(0, Math.min(root.emergenceX + (root.separatedX - root.emergenceX) * root.entranceProgress,
        parent.width - root.width))
    property real animatedRestingY: root.restingY
    Behavior on animatedRestingY {
        enabled: !Config.reducedMotion
        Spring { id: verticalSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }
    y: root.emergenceY + (root.animatedRestingY - root.emergenceY) * root.entranceProgress
    Behavior on animatedAnchorX {
        enabled: !Config.reducedMotion
        Spring { id: anchorSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }

    readonly property real _expandedWidth: expandedLoader.item ? expandedLoader.item.implicitWidth + root.padH * 2 : root.badgeWidth
    readonly property real _expandedHeight: expandedLoader.item ? expandedLoader.item.implicitHeight + root.padV * 2 : root.badgeSize

    readonly property real desiredWidth: root.expanded ? Math.min(root._expandedWidth, Config.islandMaxWidth, parent.width) : root.badgeWidth
    readonly property real desiredHeight: root.expanded ? Math.max(root.badgeSize, Math.min(root._expandedHeight, Config.islandMaxHeight, parent.height - root.y)) : root.badgeSize
    width: root.desiredWidth
    height: root.desiredHeight
    Behavior on width {
        enabled: !Config.reducedMotion
        Spring { id: widthSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }
    Behavior on height {
        enabled: !Config.reducedMotion
        Spring { id: heightSpring; spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }

    opacity: root.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        enabled: !Config.reducedMotion
        NumberAnimation { id: visibilityFade; duration: root.shown ? Config.animFast : Config.animSlow; easing.type: Easing.OutCubic }
    }

    Connections {
        target: Config
        function onReducedMotionChanged() {
            if (!Config.reducedMotion) return;
            // SpringAnimation has no duration, so complete() cannot settle it.
            // Stop live motion and restore bindings with Behaviors disabled.
            entranceSpring.stop();
            placementSpring.stop();
            verticalSpring.stop();
            anchorSpring.stop();
            widthSpring.stop();
            heightSpring.stop();
            visibilityFade.stop();
            root.entranceProgress = Qt.binding(() => root.shown ? 1 : 0);
            root.belowProgress = Qt.binding(() => root.below ? 1 : 0);
            root.animatedRestingY = Qt.binding(() => root.restingY);
            root.animatedAnchorX = Qt.binding(() => root.desiredAnchorX);
            root.width = Qt.binding(() => root.desiredWidth);
            root.height = Qt.binding(() => root.desiredHeight);
            root.opacity = Qt.binding(() => root.shown ? 1 : 0);
        }
    }

    transform: Scale {
        // Stretch toward the Island during separation, then recover the badge's
        // round shape. Derive both axes from the live spring so reversal stays
        // continuous, with no extra animation or bounce outside the preset.
        readonly property real progress: Math.max(0, Math.min(1, root.entranceProgress))
        readonly property real stretch: 4 * progress * (1 - progress)
        origin.x: root.onRight ? 0 : root.width
        origin.y: root.height / 2
        xScale: Config.reducedMotion ? 1 : 0.92 + 0.08 * progress + 0.12 * stretch
        yScale: Config.reducedMotion ? 1 : 0.92 + 0.08 * progress - 0.06 * stretch
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
            Behavior on opacity {
                enabled: !Config.reducedMotion
                NumberAnimation { duration: Config.animFast; easing.type: Easing.OutCubic }
            }
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
