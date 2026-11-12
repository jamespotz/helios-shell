import QtQuick
import "../../services"

// Where one screen's Island sits and how big it is. Island.qml and its
// satellites bind to this instead of each other's internals, and tests
// drive it with plain values. Layout modes (Notch, Zen) resolve here.
QtObject {
    id: root

    // Inputs, set by Island.qml.
    property string mode: "idle"
    property bool expanded: false
    // The content Loader's item and its implicit size; contentReady is false
    // for the frame a fresh open is still instantiating it.
    property bool contentReady: false
    property real contentWidth: 0
    property real contentHeight: 0
    property real surfaceWidth: Config.islandMaxWidth
    property real screenHeight: 0
    // An expanded satellite placed below the Island takes room from it.
    property bool satelliteBelow: false
    // The painted shape's live (springing) width.
    property real paintedWidth: 0

    // Zen: the idle Island hides above the screen edge, leaving a thin
    // strip at the top that opens peek on hover.
    readonly property bool zenHidden: Config.islandAutoHide && root.mode === "idle"
    // Idle forces 0 regardless of the configured value.
    readonly property int padH: root.mode === "idle" ? 0 : Config.islandContentPadH
    readonly property int padV: root.mode === "idle" ? 0 : Config.islandContentPadV

    // Reserves the whole idle bump plus a gap below it, independent of mode:
    // expanded states overlap windows instead of growing this. The top gap
    // lives inside the surface and Hyprland adds a margin on top of this
    // zone, so the gap below (islandWindowGap) is added here.
    // Zen reserves only the gap (Hyprland's top gaps_out is 0, so this is
    // the windows' top gap): they take the height under the hidden Island.
    readonly property int exclusiveZone: Config.islandAutoHide
        ? Config.islandWindowGap : Config.islandExclusiveZone + Config.islandWindowGap

    // The layer-shell surface never resizes (see Island.qml). It starts at
    // the screen edge and the Island sits islandTopGap below it, so the
    // shadow has room to blur upward.
    readonly property real surfaceHeight: Config.islandTopGap + Math.min(Config.islandMaxHeight,
        root.screenHeight > 0 ? root.screenHeight - Config.islandTopGap : Config.islandMaxHeight)
    readonly property real islandHeight: root.surfaceHeight - Config.islandTopGap
    // Clamped to the surface: content past it would be hard-cut square by
    // the surface edge instead of the Island's rounded clip.
    readonly property real maxWidth: Math.min(Config.islandMaxWidth, root.surfaceWidth)
    readonly property real maxHeight: Math.min(Config.islandMaxHeight, root.islandHeight)

    // The hit area snaps to its target with no animation and owns the mask.
    // While a fresh open's content is still loading it falls back to the
    // full size, so clicks inside the opening panel never miss the input
    // region.
    readonly property real hitTop: root.zenHidden ? 0 : Config.islandTopGap
    readonly property real hitWidth: root.contentReady ? Math.min(root.contentWidth + root.padH * 2, root.maxWidth)
        : root.expanded ? root.maxWidth : Math.min(Config.idleBumpWidth, root.surfaceWidth)
    readonly property real hitHeight: root.zenHidden ? 4
        : root.contentReady ? Math.min(root.contentHeight + root.padV * 2, root.maxHeight)
        : root.expanded ? root.maxHeight : Math.min(Config.idleBumpHeight, root.islandHeight)

    // The painted shape's spring target. Unlike the hit area it never
    // follows the full-size fallback, so the shape doesn't balloon for a
    // frame on a fresh open before settling to the content size.
    property int paintTargetWidth: Config.idleBumpWidth
    property int paintTargetHeight: Config.idleBumpHeight
    readonly property list<QtObject> _paintTargets: [
        Binding { target: root; property: "paintTargetWidth"; when: root.contentReady; value: root.hitWidth },
        Binding { target: root; property: "paintTargetHeight"; when: root.contentReady
            value: Math.min(root.contentHeight + root.padV * 2, root.maxHeight) },
        Binding { target: root; property: "paintTargetWidth"; when: !root.contentReady && !root.expanded; value: Config.idleBumpWidth },
        Binding { target: root; property: "paintTargetHeight"; when: !root.contentReady && !root.expanded; value: Config.idleBumpHeight }
    ]

    // The painted shape is centred in the surface; Notch satellites follow
    // these live edges rather than the hit area's, which jump.
    readonly property real paintedLeft: (root.surfaceWidth - root.paintedWidth) / 2
    readonly property real paintedRight: (root.surfaceWidth + root.paintedWidth) / 2

    // Kept free beyond the content height handed to an IslandDestinationHost
    // (the Island's own, or a Satellite's through SatelliteDestinationHost):
    // the host's chrome (spacing + margin, 22 px) plus breathing room.
    // tst_island_geometry checks the chrome still fits.
    readonly property int destinationChrome: 60
    readonly property real destinationMaxWidth: Math.max(0, root.maxWidth - root.padH * 2)
    readonly property real destinationMaxHeight: Math.max(0, root.islandHeight - root.padV * 2 - root.destinationChrome
        - (root.satelliteBelow ? root.islandHeight / 2 + Config.satelliteRestGap : 0))
    // A satellite destination's room below the Island's top, halved when
    // it sits below the Island.
    function satelliteMaxHeight(below, padV) {
        return Math.max(0, root.surfaceHeight - root.hitTop - (below ? root.surfaceHeight / 2 : 0)
            - padV * 2 - root.destinationChrome);
    }
}
