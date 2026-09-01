import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../../services"

// The whole bar is the island: a small idle bump top-center on each screen
// that morphs open on hover (workspaces/clock/tray/status), for a
// notification, for media, or for the volume/Bluetooth/Wifi panel — instead
// of staying a fixed full-width pill.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    readonly property bool panelOpen: Bridge.islandOpen && Bridge.islandScreen === modelData.name
    readonly property bool notifyMode: !panelOpen && Notifications.state.popups.length > 0
    property bool hovering: false
    readonly property bool expanded: panelOpen || notifyMode || hovering

    readonly property string mode: panelOpen ? Bridge.islandTab
        : notifyMode ? "notify"
        : hovering ? "peek"
        : "idle"

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
    WlrLayershell.keyboardFocus: bar.expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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
        interval: 260
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
            if (bar.panelOpen) Bridge.closeIsland();
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

    // hitArea snaps to its target size *instantly* — no Behavior — and owns
    // the mask + hover MouseArea. visual (below) animates to match it. If the
    // hit-test region itself were mid-spring (and springs can overshoot past
    // their target before settling), its edge would sweep back and forth
    // across the cursor as it settled, each crossing toggling `hovering` and
    // re-triggering the animation — a feedback loop that reads as the whole
    // bar/icons flickering. Keeping the hit area stable from the first frame
    // of a mode change avoids that entirely; only the paint layer animates.
    Item {
        id: hitArea
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

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
            anchors.fill: parent
            focus: bar.expanded
            Keys.onEscapePressed: {
                if (bar.panelOpen) Bridge.closeIsland();
                else if (bar.notifyMode) Notifications.dismissAll();
                else bar.hovering = false;
            }
        }

        Item {
            id: visual
            anchors.centerIn: parent
            width: hitArea.width
            height: hitArea.height

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
                    anchors.centerIn: parent
                    opacity: 0
                    sourceComponent: bar.panelOpen ? panelComp
                        : bar.notifyMode ? notifyComp
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

    Component { id: idleComp; IdleBump { mediaPlaying: bar.hasActiveMedia; targetScreen: bar.screen } }
    Component { id: peekComp; PeekContent { targetScreen: bar.screen } }
    Component { id: notifyComp; NotifyCard {} }
    Component { id: panelComp; PanelWrapper {} }
}
