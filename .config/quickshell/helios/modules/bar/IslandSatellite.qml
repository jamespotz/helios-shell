import QtQuick
import "../../services"
import "../../components"

// Shared chrome for the small badges that flank the island (recording
// status, maintenance alerts). Liquid-pops in from the island's edge when
// `active` turns on, and — for badges that opt in via `interactive` — can
// morph in place into a full panel via `expanded`, using the exact same
// spring behavior as the main island's own hitArea/visual morph so both
// reveals read as one consistent motion language.
Item {
    id: root

    // hitArea never animates its own width/height (see Bar.qml's comment on
    // hitArea), so positioning off its edges directly would drag this
    // satellite along in the same instant jump. x below springs instead.
    required property Item anchorItem
    property bool onRight: false
    property real restGap: 6

    property bool active: false
    property bool expanded: false
    property bool interactive: false

    property int badgeSize: 32
    property int padH: 10
    property int padV: 10

    property color fillColor: Colors.surface
    property bool shadowEnabled: true
    // Small enough that the blur doesn't reach past restGap into the
    // island's own shadow — keeps a visible shadow without the two merging
    // into a bridge across the gap.
    property real shadowGlowRadius: 5
    property real shadowSpread: 0

    property Component badge
    property Component expandedContent

    signal clicked()

    property real gap: 0

    anchors.top: anchorItem.top
    x: root.onRight ? anchorItem.x + anchorItem.width + gap : anchorItem.x - width - gap
    Behavior on x {
        SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
    }

    readonly property int _expandedWidth: expandedLoader.item ? expandedLoader.item.implicitWidth + root.padH * 2 : root.badgeSize
    readonly property int _expandedHeight: expandedLoader.item ? expandedLoader.item.implicitHeight + root.padV * 2 : root.badgeSize

    width: root.expanded ? Math.min(root._expandedWidth, Config.islandMaxWidth) : root.badgeSize
    height: root.expanded ? Math.min(root._expandedHeight, Config.islandMaxHeight) : root.badgeSize
    Behavior on width {
        SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
    }
    Behavior on height {
        SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
    }

    opacity: root.active || root.expanded ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    transform: Scale {
        id: liquidScale
        origin.x: root.width / 2
        origin.y: root.height / 2
        xScale: 1.0
        yScale: 1.0
    }

    // Quickshell can start (or reload) with `active` already true — no
    // change notification fires for a value already set before this Item
    // existed, so without this the badge would sit at gap: 0, scale: 1
    // (flush against the island, not yet "pulled out") until the next
    // on/off cycle.
    Component.onCompleted: {
        if (root.active) root.gap = root.restGap;
    }

    onActiveChanged: {
        // Stopping any in-flight tween first avoids it fighting a freshly
        // started one — a quick off/on in close succession could otherwise
        // leave the animation mid-glitch.
        liquidSlideIn.stop();

        if (root.active) {
            // Jump to the stretched starting shape instantly, while still
            // invisible (opacity is still fading in), then let a single
            // elastic tween carry both the pull-away and the round-out back
            // to normal — one continuous curve, not several stitched ones.
            root.gap = 0;
            liquidScale.xScale = 1.32;
            liquidScale.yScale = 0.76;
            liquidSlideIn.start();
        } else {
            root.gap = 0;
            liquidScale.xScale = 1.0;
            liquidScale.yScale = 1.0;
        }
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
        fillColor: root.fillColor
        shadowEnabled: root.shadowEnabled
        shadowGlowRadius: root.shadowGlowRadius
        shadowSpread: root.shadowSpread
    }

    // Clips both loaders to the badge's own rounded shape — needed now that
    // expandedLoader below is resident even while collapsed: without this,
    // the full-size panel content would poke out past the tiny 38px circle
    // instead of just being masked by it until the container grows to meet
    // it. A plain Item's clip is a hard rectangle, so this borrows
    // IslandShape's own cornerRadius (see Bar.qml's identical reasoning for
    // its content Rectangle) to keep the corners rounded while clipping.
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
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // Loaded as soon as expandedContent is set — not gated on `expanded`
        // — so the panel (and its own async-loaded island content) is
        // already instantiated and measured by the time the badge is
        // clicked, and pinned to the corner the badge itself grows from
        // (fixed top/left, same as root's own x/width growth below) rather
        // than centered — centering it re-anchored to a shifting midpoint
        // as the container widened, which read as the content sliding
        // sideways instead of the container simply revealing more of it.
        // No fade Behavior either: opacity switches the instant `expanded`
        // does, so the panel just appears already in place as the badge
        // grows around it, instead of cross-fading on its own timeline.
        Loader {
            id: expandedLoader
            anchors.top: parent.top
            anchors.topMargin: root.padV
            anchors.left: parent.left
            anchors.leftMargin: root.padH
            active: !!root.expandedContent
            enabled: root.expanded
            sourceComponent: root.expandedContent
            opacity: root.expanded && expandedLoader.item ? 1 : 0
        }
    }

    MouseArea {
        anchors.fill: parent
        // Disabled once expanded so clicks reach the panel's own controls
        // (close button, scroll, buttons) instead of this toggle.
        visible: root.interactive && !root.expanded
        enabled: root.interactive && !root.expanded
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
