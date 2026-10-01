import QtQuick
import "../../services"
import "../../components"

// Shared chrome for the small badges that flank the island (recording
// status, maintenance alerts). Liquid-pops in from the island's edge when
// `active` turns on, and — for badges that opt in via `interactive` — can
// morph in place into a full panel via `expanded`, using the exact same
// spring behavior as the main island's own hitArea/visual morph so both
// reveals read as one consistent motion language.
FocusScope {
    id: root

    // hitArea never animates its own width/height (see Bar.qml's comment on
    // hitArea), so positioning off its edges directly would drag this
    // satellite along in the same instant jump. x below springs instead.
    required property Item anchorItem
    property bool onRight: false
    property real restGap: Config.satelliteRestGap

    property bool active: false
    property bool expanded: false
    property bool interactive: false
    property string label: ""
    readonly property bool shown: root.active || root.expanded

    property int badgeSize: Config.satelliteBadgeSize
    property int padH: Config.satellitePadH
    property int padV: Config.satellitePadV

    property color fillColor: Colors.surface
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

    // Same escape-to-close as the main island's hitArea (Bar.qml) — focus
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
    readonly property real desiredX: root.below
        ? anchorItem.x + (anchorItem.width - root.width) / 2
        : root.onRight ? anchorItem.x + anchorItem.width + gap : anchorItem.x - width - gap
    property real animatedX: root.desiredX
    // The spring may lag a growing Island. Clamp its position so the
    // destination never crosses the Island's interactive bounds.
    readonly property real separatedX: root.below ? root.animatedX
        : root.onRight ? Math.max(root.animatedX, anchorItem.x + anchorItem.width + gap)
        : Math.min(root.animatedX, anchorItem.x - root.width - gap)
    x: Math.max(0, Math.min(root.separatedX, parent.width - root.width))
    y: root.below ? anchorItem.y + anchorItem.height + root.restGap : anchorItem.y
    Behavior on animatedX {
        enabled: !Config.reducedMotion
        SpringAnimation { spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }

    readonly property int _expandedWidth: expandedLoader.item ? expandedLoader.item.implicitWidth + root.padH * 2 : root.badgeSize
    readonly property int _expandedHeight: expandedLoader.item ? expandedLoader.item.implicitHeight + root.padV * 2 : root.badgeSize

    width: root.expanded ? Math.min(root._expandedWidth, Config.islandMaxWidth, parent.width) : root.badgeSize
    height: root.expanded ? Math.max(root.badgeSize, Math.min(root._expandedHeight, Config.islandMaxHeight, parent.height - root.y)) : root.badgeSize
    Behavior on width {
        enabled: !Config.reducedMotion
        SpringAnimation { spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }
    Behavior on height {
        enabled: !Config.reducedMotion
        SpringAnimation { spring: Config.satelliteSpringStiffness; damping: Config.satelliteSpringDamping }
    }

    opacity: root.shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        enabled: !Config.reducedMotion
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
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
        liquidScale.xScale = 1;
        liquidScale.yScale = 1;
        if (root.shown && animate && !Config.reducedMotion) {
            root.gap = 0;
            liquidScale.xScale = 1.32;
            liquidScale.yScale = 0.76;
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
        NumberAnimation { target: root; property: "gap"; to: root.restGap; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
        NumberAnimation { target: liquidScale; property: "xScale"; to: 1.0; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
        NumberAnimation { target: liquidScale; property: "yScale"; to: 1.0; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
    }

    IslandShape {
        id: islandShape
        anchors.fill: parent
        radiusLimit: 18
        borderEnabled: Config.satelliteBorder
        borderWidth: Config.satelliteBorderWidth
        fillColor: root.fillColor
        shadowEnabled: root.shadowEnabled
        shadowGlowRadius: root.shadowGlowRadius
        shadowSpread: root.shadowSpread
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
            Behavior on opacity { enabled: !Config.reducedMotion; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // Closed satellites must not instantiate destinations with background work.
        Loader {
            id: expandedLoader
            anchors.top: parent.top
            anchors.topMargin: root.padV
            anchors.left: parent.left
            anchors.leftMargin: root.padH
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
