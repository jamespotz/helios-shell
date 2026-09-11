import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../../services"
import "../../components"

// The whole bar is the island: a small idle bump top-center on each screen
// that morphs open on hover (workspaces/clock/tray/status), for a
// notification, for media, or for the volume/Bluetooth/Wifi panel — instead
// of staying a fixed full-width pill.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property bool panelOpen: IslandNavigation.panelOpenFor(modelData.name)
    property bool hovering: false
    readonly property string mode: IslandNavigation.modeFor(modelData.name, hovering)
    readonly property bool expanded: IslandNavigation.expandedFor(modelData.name, hovering)
    readonly property bool notifyMode: mode === "notify"
    readonly property bool taskMode: mode === "task"
    readonly property bool meetingMode: mode === "meeting"
    readonly property bool batteryMode: mode === "battery"

    readonly property bool hasActiveMedia: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.some(p => p.isPlaying);
    }

    readonly property int padH: mode === "idle" ? 0 : 18
    readonly property int padV: mode === "idle" ? 0 : 10

    // The one seam for "something is temporarily covering the island, so
    // its close/collapse triggers should hold off" — right now that's just
    // the custom tray menu, but a future reason to suppress adds one clause
    // here instead of a new copy of the check at another call site.
    readonly property bool suppressCollapse: Bridge.trayMenuOpen

    // Top, not Overlay: the bar is a persistent panel, and popups (launcher,
    // OSD, power menu, keybind cheatsheet) need to render strictly above it.
    // wlr-layer-shell only guarantees stacking order *between* layers
    // (background < bottom < top < overlay) — same-layer ordering is
    // compositor-dependent, and putting both on Overlay let this
    // always-mapped bar win that tie and cover popups' dim backdrops
    // instead of being covered by them.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "helios:bar"
    // IPC-opened panel content needs immediate keyboard focus for search
    // fields and shortcuts. Passive cards must never steal keyboard input
    // from the active application when they appear.
    WlrLayershell.keyboardFocus: bar.panelOpen ? WlrKeyboardFocus.Exclusive
        : bar.expanded ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    anchors.top: true
    // A small gap from the true screen edge so the pill's top-corner
    // rounding actually reads as rounded, instead of being flush-cut.
    margins.top: Config.islandTopGap
    // Reserves enough room for the *whole* idle bump plus a visible gap
    // below it, not just the top margin — otherwise a maximized window's
    // title bar sits flush against the bump with no breathing room. This is
    // a flat constant independent of `mode`, so the gap holds even when the
    // island expands (expanded states overlap windows instead of pushing
    // this reservation any bigger).
    exclusiveZone: Config.islandExclusiveZone
    color: "transparent"

    // The real layer-shell surface never resizes — only the item(s) inside it
    // do. Animating the actual Wayland surface size every frame is what made
    // the morph stutter (each frame needs a compositor resize/configure
    // round-trip); a fixed window with an animated child item is pure GPU
    // compositing, which stays smooth. `mask` keeps the rest of this window
    // click-through so it doesn't eat input outside the visible pill.
    implicitWidth: Config.islandMaxWidth
    implicitHeight: Config.islandMaxHeight
    mask: Region { item: hitArea }

    Timer {
        id: hoverCollapseTimer
        interval: Config.hoverCollapseDelay
        // Tray icons only ever render in the peek (hover-expanded) row —
        // see PeekContent.qml/IdleBump.qml — so while our custom tray menu
        // is open, the cursor leaves the island (it's on the overlay menu
        // surface now), which fires this timer. Poll instead of collapsing
        // while the menu is still visible; a genuine hover return still
        // cancels this timer normally (see hoverTracker.onHoveredChanged).
        onTriggered: {
            if (bar.suppressCollapse) { hoverCollapseTimer.restart(); return; }
            bar.hovering = false;
        }
    }

    // Click-outside-closes. Previously this fired on EVERY click, not just
    // outside ones — traced to `hitArea` briefly falling back to the tiny
    // idle-bump size while the panel's content Loader was still
    // instantiating on a fresh open (fixed below), which raced with
    // grabbing focus before Hyprland had the real (expanded) input region
    // registered. Delaying `active` until just after panelOpen flips avoids
    // grabbing mid-transition; `cleared` still carries no location, so it's
    // only safe to treat as "outside" now that the race is closed.
    Timer {
        id: focusGrabDelay
        interval: 80
        onTriggered: focusGrab.active = true
    }

    onPanelOpenChanged: {
        if (panelOpen) focusGrabDelay.restart();
        else { focusGrabDelay.stop(); focusGrab.active = false; }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [bar]
        active: false
        onCleared: {
            if (bar.suppressCollapse) return;
            if (bar.panelOpen) IslandNavigation.close();
        }
    }

    // Re-arm the focus grab when the tray menu closes — the grab was
    // already lost the instant the overlay stole focus, so if the island
    // is still open after the menu closes, we need to re-establish it so
    // a genuine outside click afterward still dismisses the island.
    Connections {
        target: Bridge
        function onTrayMenuOpenChanged() {
            if (!bar.suppressCollapse && bar.panelOpen) {
                focusGrab.active = false;
                focusGrabDelay.restart();
            }
        }
    }

    // visual's spring target while content.item is momentarily null on a
    // fresh open (see hitArea below). Bindings only fire while content.item
    // is valid or the island is idle — during the null-but-expanded gap
    // neither applies, so this just holds its last real value instead of
    // jumping to hitArea's islandMaxWidth/Height click-safety fallback,
    // which was making the pill itself balloon to full size for a frame
    // before settling to the real content size.
    property int visualTargetWidth: Config.idleBumpWidth
    property int visualTargetHeight: Config.idleBumpHeight

    Binding on visualTargetWidth {
        when: content.item !== null
        value: Math.min(content.item ? content.item.implicitWidth + bar.padH * 2 : 0, Config.islandMaxWidth)
    }
    Binding on visualTargetHeight {
        when: content.item !== null
        value: Math.min(content.item ? content.item.implicitHeight + bar.padV * 2 : 0, Config.islandMaxHeight)
    }
    Binding on visualTargetWidth {
        when: content.item === null && !bar.expanded
        value: Config.idleBumpWidth
    }
    Binding on visualTargetHeight {
        when: content.item === null && !bar.expanded
        value: Config.idleBumpHeight
    }

    // hitArea snaps to its target size *instantly* — no Behavior — and owns
    // the mask + hover MouseArea. visual (below) tracks its own target
    // (visualTargetWidth/Height above), which usually matches hitArea but
    // deliberately diverges during the fresh-open content.item gap so the
    // paint layer doesn't spring toward hitArea's islandMaxWidth/Height
    // click-safety fallback. If the hit-test region itself were mid-spring
    // (and springs can overshoot past their target before settling), its
    // edge would sweep back and forth across the cursor as it settled, each
    // crossing toggling `hovering` and re-triggering the animation — a
    // feedback loop that reads as the whole bar/icons flickering. Keeping
    // the hit area stable from the first frame of a mode change avoids that
    // entirely; only the paint layer animates.
    Item {
        id: hitArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        focus: bar.expanded
        // Has to live here, not on some deeper wrapper — key events bubble
        // up the visual *parent* chain from whatever grabbed active focus
        // (e.g. a tab's own ListView/TextField), and this is the shallowest
        // real ancestor of every panel tab's content (visual > Rectangle >
        // Loader). A sibling of `visual` never sees keys typed into it.
        Keys.onEscapePressed: {
            IslandNavigation.dismiss(bar.modelData.name, bar.mode);
            if (!bar.panelOpen && !bar.notifyMode && !bar.meetingMode && !bar.batteryMode)
                bar.hovering = false;
        }

        // Falling all the way back to the tiny idle-bump size while
        // `content.item` is still null (the Loader hasn't finished
        // instantiating PanelWrapper/NotifyCard/PeekContent yet — true for
        // one frame on every *fresh* open, though never on a tab switch
        // within an already-open panel, since content.item there never goes
        // null) put the mask's real input region there for that frame. On a
        // fresh open, clicks inside the visually-full-size panel landed
        // outside that actual (still tiny) input region and fell through to
        // whatever's behind — reproduced live: every row/button in a
        // freshly-opened panel silently ate clicks, while the exact same
        // click after a tab switch worked. Falling back to the full max
        // size instead (while expanded) means the mask is never smaller
        // than the real content, so a stray click at worst hits inert
        // padding instead of missing the window entirely.
        // Clamped to islandMaxWidth/Height — the real layer-shell surface
        // (bar's implicitWidth/implicitHeight, below) never grows past that
        // fixed size, so an unclamped content size here (e.g. a long window
        // title pushing the idle/peek row past the surface's fixed width)
        // would get hard-cut by the surface edge itself: square, no
        // rounding, past the mask entirely. Clamping keeps overflow inside
        // the visual's own rounded-corner clip below instead.
        width: content.item ? Math.min(content.item.implicitWidth + bar.padH * 2, Config.islandMaxWidth)
            : bar.expanded ? Config.islandMaxWidth : Config.idleBumpWidth
        height: content.item ? Math.min(content.item.implicitHeight + bar.padV * 2, Config.islandMaxHeight)
            : bar.expanded ? Config.islandMaxHeight : Config.idleBumpHeight

        // A plain MouseArea here would lose hover the instant the cursor moves
        // onto a nested IconButton's own MouseArea (overlapping MouseAreas
        // deliver hover exclusively to the topmost one) — that fired exited on
        // every icon underneath, restarting the collapse timer while you were
        // still over the island. HoverHandler tracks this item's bounds
        // independently of whatever's painted on top of it, so it doesn't.
        HoverHandler {
            id: hoverTracker
            onHoveredChanged: {
                if (hoverTracker.hovered) { hoverCollapseTimer.stop(); bar.hovering = true; }
                else hoverCollapseTimer.restart();
            }
        }

        Item {
            id: visual
            // Anchored to hitArea's fixed top edge and horizontal center
            // (not centerIn) — growing width still expands left/right
            // symmetrically, but growing height now extends only downward
            // instead of also pushing the top edge upward.
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: bar.visualTargetWidth
            height: bar.visualTargetHeight

            // Both axes share identical spring params so they stay in
            // lockstep — mismatched width/height easing is what makes a
            // morph read as sloppy.
            Behavior on width {
                SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
            }
            Behavior on height {
                SpringAnimation { spring: Config.islandSpringStiffness; damping: Config.islandSpringDamping }
            }

            IslandShape {
                id: islandShape
                anchors.fill: parent
                liquidGlassEnabled: Bridge.liquidGlassEnabled
                fillColor: bar.mode === "idle" ? Colors.background : Colors.surface
            }

            // A plain Item's clip is a hard rectangle — if content ever runs
            // wider or taller than expected (a long window title, or a tab
            // whose height estimate was off), it sliced straight through the
            // pill's rounded corners instead of just cutting content off
            // with the shape intact. Reusing IslandShape's own cornerRadius
            // here (rather than a separately-tuned formula that could drift
            // from it) means an overflow now degrades to "cut off, still a
            // rounded pill" instead of "cut off with flat square corners".
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: islandShape.cornerRadius
                clip: true

                Loader {
                    id: content
                    anchors.top: parent.top
                    anchors.topMargin: bar.padV
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0
                    sourceComponent: bar.panelOpen ? panelComp
                        : bar.notifyMode ? notifyComp
                        : bar.taskMode ? taskComp
                        : bar.meetingMode ? meetingComp
                        : bar.batteryMode ? batteryComp
                        : bar.hovering ? peekComp
                        : idleComp
                    onLoaded: contentFadeIn.restart()

                    NumberAnimation {
                        id: contentFadeIn
                        target: content
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // Recording status lives here, outside the content Loader, so it stays
    // visible across every mode (idle, peek, notify, panel) instead of
    // disappearing whenever the island's content switches.
    Item {
        id: recordingSatellite
        // hitArea.top is fixed (anchors.top: parent.top, never animated),
        // but hitArea grows *downward* when the island expands — anchoring
        // to hitArea.verticalCenter (the previous approach) rode that
        // growth and dragged this satellite down with it. Anchoring to the
        // fixed top instead, at the same height as the idle pill, keeps it
        // planted regardless of mode.
        anchors.top: hitArea.top
        anchors.right: hitArea.left
        anchors.rightMargin: gap

        readonly property real restGap: 6
        property real gap: 0
        opacity: ScreenRecorder.recording ? 1 : 0
        visible: opacity > 0.01
        // Fixed to the idle bump's own height, not hitArea's — hitArea
        // grows to whatever mode is active (peek, panel, notify), and this
        // satellite should stay pill-sized instead of expanding with it.
        width: Config.idleBumpHeight
        height: Config.idleBumpHeight

        transform: Scale {
            id: liquidScale
            origin.x: recordingSatellite.width / 2
            origin.y: recordingSatellite.height / 2
            xScale: 1.0
            yScale: 1.0
        }

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        // Quickshell can start (or reload) with ScreenRecorder.recording
        // already true — no onRecordingChanged fires for a value that was
        // already set before this Item existed, so without this the
        // satellite would sit at gap: 0, xScale: 1, yScale: 1 (flush
        // against the island, not yet "pulled out") until the next
        // start/stop cycle. This puts it straight at rest instead.
        Component.onCompleted: {
            if (ScreenRecorder.recording) recordingSatellite.gap = recordingSatellite.restGap;
        }

        Connections {
            target: ScreenRecorder
            function onRecordingChanged() {
                // Stopping any in-flight tween first avoids it fighting a
                // freshly-started one — without this, a quick stop/start
                // (or start/stop) in close succession could leave the
                // animation mid-glitch, animating from a stale in-progress
                // value instead of the clean starting point set below.
                liquidSlideIn.stop();

                if (ScreenRecorder.recording) {
                    // Jump to the stretched starting shape instantly, while
                    // still invisible (opacity is still fading in), then
                    // let a single elastic tween carry both the pull-away
                    // and the round-out back to normal. One continuous
                    // curve per property, not several stitched together —
                    // chained NumberAnimations each start/stop at zero
                    // velocity, so every join reads as a visible kink
                    // instead of one fluid motion.
                    recordingSatellite.gap = 0;
                    liquidScale.xScale = 1.32;
                    liquidScale.yScale = 0.76;
                    liquidSlideIn.start();
                } else {
                    recordingSatellite.gap = 0;
                    liquidScale.xScale = 1.0;
                    liquidScale.yScale = 1.0;
                }
            }
        }

        // Pulls out to its resting gap while the stretched departure shape
        // rounds back to normal, both on one elastic curve so the whole
        // move reads as a single liquid pull rather than a rigid icon
        // sliding on rails. A gentler amplitude/period than a typical
        // "bouncy" elastic — reads as surface tension settling, not a
        // rubber-ball bounce.
        ParallelAnimation {
            id: liquidSlideIn
            NumberAnimation { target: recordingSatellite; property: "gap"; to: recordingSatellite.restGap; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
            NumberAnimation { target: liquidScale; property: "xScale"; to: 1.0; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
            NumberAnimation { target: liquidScale; property: "yScale"; to: 1.0; duration: 720; easing.type: Easing.OutElastic; easing.amplitude: 0.25; easing.period: 0.45 }
        }

        IslandShape {
            anchors.fill: parent
            fillColor: Colors.surface
        }

        RecordingDot { anchors.centerIn: parent }
    }

    Component { id: idleComp; IdleBump { mediaPlaying: bar.hasActiveMedia; targetScreen: bar.screen } }
    Component { id: peekComp; PeekContent { targetScreen: bar.screen } }
    Component { id: notifyComp; NotifyCard {} }
    Component { id: taskComp; TaskCard {} }
    Component { id: meetingComp; MeetingCard {} }
    Component { id: batteryComp; BatteryAlertCard {} }
    Component { id: panelComp; PanelWrapper {} }
}
