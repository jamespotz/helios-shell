import QtQuick
import QtQuick.Shapes
import QtMultimedia
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "../../services"

// One background-layer surface per screen, sitting below every real window
// (and below the island's overlay layer) — set via the island's wallpaper
// panel or `ipc call wallpaper set <path>`.
//
// The reveal animation played whenever the wallpaper changes is modular:
// `stage.revealStyle` (mirrors Config.wallpaperRevealStyle) picks one of
// eight modules, each self-contained below. "random" (the default) picks a
// different one on every change instead of a fixed style.
PanelWindow {
    id: wallpaper

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "helios:wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors { top: true; bottom: true; left: true; right: true }
    // -1, not 0: per wlr-layer-shell, 0 means "shrink to avoid other
    // surfaces' exclusive-zone reservations" (which is exactly what was
    // carving the island's reserved top strip out of the wallpaper as a
    // plain black bar) — -1 means "ignore reservations, fill the whole
    // anchored area regardless." The island still draws on top of this
    // since it's on the Overlay layer, well above Background.
    exclusiveZone: -1
    color: Colors.background

    Item {
        id: stage
        anchors.fill: parent
        clip: true

        // --- Core state -----------------------------------------------------
        // `bgOld` is never reactive — it only ever holds a frozen snapshot of
        // whatever `bgNew` was showing right before the wallpaper changed, and
        // sits statically underneath (z fixed at 0, never swapped). `bgNew` is
        // a plain direct binding to Wallpaper.source (z fixed at 1), so it can
        // never get stuck showing a stale image. Every reveal module below
        // only ever animates properties of these two items (or paints over
        // them at z >= 2) — none of them do manual top/bottom bookkeeping, so
        // there's nothing for them to desync.
        property string prevSource: ""
        property bool awaitingReady: false
        property bool transitioning: false
        readonly property string revealStyle: Config.wallpaperRevealStyle
        readonly property var allStyles: ["blur", "glitch", "liquid", "grid", "neon", "honeycomb", "blinds"]
        readonly property bool videoShouldPlay: Wallpaper.isVideo && !Bridge.locked && !UPower.onBattery
        onVideoShouldPlayChanged: videoPlayer.sync()

        function pickStyle() {
            return stage.revealStyle === "random"
                ? stage.allStyles[Math.floor(Math.random() * stage.allStyles.length)]
                : stage.revealStyle;
        }

        function transitionFinished() { stage.transitioning = false }

        function beginTransition() {
            bgOld.source = stage.prevSource;
            bgOld.opacity = 1;
            stage.prevSource = Wallpaper.source;
            stage.awaitingReady = Wallpaper.source !== "";
            driftAnim.stop();
            bgNew.scale = 1;
            bgNew.x = 0;
            bgNew.y = 0;
            bgNew.opacity = 1;
        }

        function playTransition() {
            stage.awaitingReady = false;
            stage.transitioning = true;
            fadeOld.restart();

            switch (stage.pickStyle()) {
            case "blur": blurModule.play(); break;
            case "glitch": glitchModule.play(); break;
            case "liquid": liquidModule.play(); break;
            case "grid": gridModule.play(); break;
            case "neon": neonModule.play(); break;
            case "blinds": revealModule.play("blinds"); break;
            default: revealModule.play("honeycomb"); break;
            }
        }

        Image {
            id: bgOld
            anchors.fill: parent
            visible: source !== "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            z: 0
        }

        Image {
            id: bgNew
            anchors.fill: parent
            visible: !Wallpaper.isVideo && source !== "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            z: 1
            source: Wallpaper.source

            onStatusChanged: if (stage.awaitingReady && status === Image.Ready) stage.playTransition()
        }

        // playbackState is read-only on MediaPlayer — drive it with
        // play()/pause() instead of binding to it directly. And this
        // Qt6Multimedia build's VideoOutput has no `source` property (only
        // `videoSink`) — the supported wiring is MediaPlayer.videoOutput,
        // not VideoOutput.source.
        MediaPlayer {
            id: videoPlayer
            source: Wallpaper.isVideo ? Wallpaper.source : ""
            loops: MediaPlayer.Infinite
            audioOutput: null
            videoOutput: bgVideo

            function sync() { stage.videoShouldPlay ? play() : pause() }
            onSourceChanged: sync()
            Component.onCompleted: sync()
        }

        VideoOutput {
            id: bgVideo
            anchors.fill: parent
            visible: Wallpaper.isVideo
            z: 1
            fillMode: VideoOutput.PreserveAspectCrop
        }

        // A slow, near-imperceptible drift on the resting wallpaper — the
        // same "living wallpaper" touch noctalia-shell uses — instead of a
        // perfectly static image once a transition settles.
        SequentialAnimation {
            id: driftAnim
            loops: Animation.Infinite
            running: !Wallpaper.isVideo && !stage.awaitingReady && !stage.transitioning && bgNew.status === Image.Ready

            NumberAnimation { target: bgNew; property: "scale"; to: 1.035; duration: 14000; easing.type: Easing.InOutSine }
            NumberAnimation { target: bgNew; property: "scale"; to: 1.0; duration: 14000; easing.type: Easing.InOutSine }
        }

        NumberAnimation {
            id: fadeOld
            target: bgOld
            property: "opacity"
            to: 0
            duration: 900
            easing.type: Easing.InOutCubic
        }

        // === 1. "blur" — Cinematic Zoom & Lens Blur ==========================
        // bgNew starts scaled up and heavily blurred, then unblurs while
        // settling to its resting scale.
        Item {
            id: blurModule

            function play() {
                bgNew.scale = 1.3;
                blurFx.radius = 64.0;
                blurFx.visible = true;
                blurAnim.restart();
            }

            FastBlur {
                id: blurFx
                anchors.fill: parent
                source: bgNew
                radius: 0
                visible: false
                z: 2
            }

            ParallelAnimation {
                id: blurAnim
                NumberAnimation { target: bgNew; property: "scale"; to: 1.0; duration: 1500; easing.type: Easing.OutQuint }
                NumberAnimation { target: blurFx; property: "radius"; to: 0.0; duration: 1500; easing.type: Easing.OutQuint }
                onFinished: { blurFx.visible = false; stage.transitionFinished(); }
            }
        }

        // === 2. "glitch" — Cyberpunk CRT Initializer =========================
        // Opacity flashes and horizontal jitter, then snaps to full clarity.
        QtObject {
            id: glitchModule
            function play() { glitchAnim.restart() }
        }

        SequentialAnimation {
            id: glitchAnim

            PropertyAction { target: bgNew; property: "opacity"; value: 0 }
            PropertyAction { target: bgNew; property: "x"; value: 0 }

            ParallelAnimation {
                SequentialAnimation {
                    loops: 5
                    NumberAnimation { target: bgNew; property: "opacity"; to: 0.8; duration: 45 }
                    NumberAnimation { target: bgNew; property: "opacity"; to: 0.2; duration: 45 }
                }
                SequentialAnimation {
                    loops: 5
                    NumberAnimation { target: bgNew; property: "x"; to: 16; duration: 35; easing.type: Easing.OutQuad }
                    NumberAnimation { target: bgNew; property: "x"; to: -16; duration: 35; easing.type: Easing.OutQuad }
                }
            }

            ParallelAnimation {
                NumberAnimation { target: bgNew; property: "opacity"; to: 1; duration: 300; easing.type: Easing.OutCubic }
                NumberAnimation { target: bgNew; property: "x"; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }

            onFinished: stage.transitionFinished()
        }

        // === 3. "liquid" — Organic Ink Shader Wipe ===========================
        // Custom GLSL: a sine-warped left-to-right edge wipes newSource over
        // oldSource. Shaders are precompiled (.qsb) — Qt6's RHI pipeline
        // doesn't accept raw GLSL strings at runtime like Qt5's ShaderEffect
        // did; see shaders/liquid.{vert,frag} for the source and
        // `qsb --qt6 -o liquid.frag.qsb liquid.frag` to rebuild them.
        Item {
            id: liquidModule

            function play() {
                bgNew.opacity = 1;
                liquidFx.progress = 0.0;
                liquidFx.visible = true;
                liquidAnim.restart();
            }

            ShaderEffect {
                id: liquidFx
                anchors.fill: parent
                visible: false
                z: 2

                property var oldSource: bgOld
                property var newSource: bgNew
                property real progress: 0.0

                vertexShader: "shaders/liquid.vert.qsb"
                fragmentShader: "shaders/liquid.frag.qsb"
            }

            NumberAnimation {
                id: liquidAnim
                target: liquidFx
                property: "progress"
                from: 0.0
                to: 1.0
                duration: 1800
                easing.type: Easing.InOutQuad
                onFinished: { liquidFx.visible = false; stage.transitionFinished(); }
            }
        }

        // === 4. "grid" — Geometric Tile Matrix Unfold ========================
        // An 8x12 grid of clipped cells, each showing the matching slice of
        // the new wallpaper (via a negative offset into a full-size copy),
        // stagger-scaling in from a corner for a sweeping diagonal wave.
        Item {
            id: gridModule
            anchors.fill: parent
            z: 2

            readonly property int cols: 12
            readonly property int rows: 8

            function play() {
                revealModule.activeKind = "grid";
                gridRepeater.model = gridModule.cols * gridModule.rows;
                revealModule.pendingCells = gridModule.cols * gridModule.rows;
                Qt.callLater(() => { for (let i = 0; i < gridRepeater.count; i++) gridRepeater.itemAt(i).trigger(); });
            }

            Repeater {
                id: gridRepeater
                model: 0

                Item {
                    id: cell
                    required property int index

                    readonly property int cx: index % gridModule.cols
                    readonly property int cy: Math.floor(index / gridModule.cols)
                    readonly property real cw: stage.width / gridModule.cols
                    readonly property real ch: stage.height / gridModule.rows

                    visible: revealModule.activeKind === "grid"
                    x: cx * cw
                    y: cy * ch
                    width: cw
                    height: ch
                    clip: true
                    scale: 0
                    transformOrigin: Item.Center

                    function trigger() { cellAnim.restart() }

                    Image {
                        source: Wallpaper.source
                        asynchronous: true
                        cache: true
                        fillMode: Image.PreserveAspectCrop
                        x: -cell.x
                        y: -cell.y
                        width: stage.width
                        height: stage.height
                    }

                    SequentialAnimation {
                        id: cellAnim
                        onFinished: revealModule.cellDone()
                        PauseAnimation { duration: (cell.cx + cell.cy) * 20 }
                        NumberAnimation { target: cell; property: "scale"; from: 0; to: 1; duration: 380; easing.type: Easing.OutBack }
                    }
                }
            }
        }

        // === 5. "neon" — Neon Outline Edge Bleed =============================
        // An opaque blackout sits over bgNew (already loaded underneath) while
        // a cyan Glow traces its thresholded silhouette; the blackout then
        // fades away as the glow fades out, revealing full color.
        Item {
            id: neonModule
            anchors.fill: parent
            z: 3
            visible: false

            function play() {
                neonModule.visible = true;
                neonBlackout.opacity = 1;
                neonGlow.opacity = 1;
                neonAnim.restart();
            }

            ThresholdMask {
                id: neonMask
                anchors.fill: parent
                source: bgNew
                threshold: 0.55
                visible: false
            }

            Rectangle {
                id: neonBlackout
                anchors.fill: parent
                // Matches the honeycomb/blinds modules' own cover tiles below
                // (both use Colors.background for the same "cover the old
                // frame" role) rather than a literal black.
                color: Colors.background
            }

            Glow {
                id: neonGlow
                anchors.fill: parent
                source: neonMask
                color: "#00fff2"
                radius: 24
                samples: 32
            }

            SequentialAnimation {
                id: neonAnim
                onFinished: { neonModule.visible = false; stage.transitionFinished(); }
                PauseAnimation { duration: 600 }
                ParallelAnimation {
                    NumberAnimation { target: neonBlackout; property: "opacity"; to: 0; duration: 500; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: neonGlow; property: "opacity"; to: 0; duration: 500; easing.type: Easing.InOutCubic }
                }
            }
        }

        // === 6/7. "honeycomb" / "blinds" — tile & strip reveals ==============
        // Covers bgNew (already sitting at rest, fully visible) with tiles
        // that shrink away in a staggered wave, so the new wallpaper looks
        // like it's being uncovered rather than crossfaded/panned in.
        Item {
            id: revealModule
            anchors.fill: parent
            z: 2

            readonly property int hexR: 64
            readonly property real hexW: hexR * 2
            readonly property real hexH: hexR * 1.7320508
            readonly property int blindCount: 16

            property var hexCells: []
            property int pendingCells: 0
            property string activeKind: ""

            function buildHexGrid() {
                const cells = [];
                const colSpacing = revealModule.hexR * 1.5;
                const rowSpacing = revealModule.hexH;
                const cols = Math.ceil(stage.width / colSpacing) + 2;
                const rows = Math.ceil(stage.height / rowSpacing) + 2;
                const ox = [0, stage.width, 0, stage.width][Math.floor(Math.random() * 4)];
                const oy = [0, 0, stage.height, stage.height][Math.floor(Math.random() * 4)];
                let maxDist = 1;
                const raw = [];
                for (let c = -1; c < cols; c++) {
                    const x = c * colSpacing;
                    const yOff = (c % 2 !== 0) ? rowSpacing / 2 : 0;
                    for (let r = -1; r < rows; r++) {
                        const y = r * rowSpacing + yOff;
                        const d = Math.hypot(x - ox, y - oy);
                        maxDist = Math.max(maxDist, d);
                        raw.push({ x: x, y: y, d: d });
                    }
                }
                for (const cellData of raw) cells.push({ x: cellData.x, y: cellData.y, delay: (cellData.d / maxDist) * 420 });
                revealModule.hexCells = cells;
            }

            function play(kind) {
                revealModule.activeKind = kind;
                if (kind === "honeycomb") {
                    revealModule.buildHexGrid();
                    hexRepeater.model = revealModule.hexCells;
                    revealModule.pendingCells = revealModule.hexCells.length;
                    Qt.callLater(() => { for (let i = 0; i < hexRepeater.count; i++) hexRepeater.itemAt(i).trigger(); });
                } else {
                    blindsRepeater.model = revealModule.blindCount;
                    revealModule.pendingCells = revealModule.blindCount;
                    Qt.callLater(() => { for (let i = 0; i < blindsRepeater.count; i++) blindsRepeater.itemAt(i).trigger(); });
                }
            }

            function cellDone() {
                revealModule.pendingCells -= 1;
                if (revealModule.pendingCells <= 0) stage.transitionFinished();
            }

            Repeater {
                id: hexRepeater
                model: 0

                Shape {
                    id: hexCell
                    required property var modelData
                    visible: revealModule.activeKind === "honeycomb"
                    x: modelData.x
                    y: modelData.y
                    width: revealModule.hexW
                    height: revealModule.hexH
                    scale: 1
                    transformOrigin: Item.Center

                    function trigger() { hexAnim.restart() }

                    ShapePath {
                        strokeWidth: -1
                        fillColor: Colors.background
                        startX: revealModule.hexW * 0.25; startY: 0
                        PathLine { x: revealModule.hexW * 0.75; y: 0 }
                        PathLine { x: revealModule.hexW; y: revealModule.hexH * 0.5 }
                        PathLine { x: revealModule.hexW * 0.75; y: revealModule.hexH }
                        PathLine { x: revealModule.hexW * 0.25; y: revealModule.hexH }
                        PathLine { x: 0; y: revealModule.hexH * 0.5 }
                        PathLine { x: revealModule.hexW * 0.25; y: 0 }
                    }

                    // Explicitly `.restart()`-triggered (from revealModule.play(),
                    // via Repeater.itemAt().trigger()) rather than bound through
                    // `running: hexCell.visible` — a `running` binding that never
                    // itself flips back to false fights the animation's own
                    // internal "finished" transition, so `onFinished` never fires
                    // and the reveal never reports completion.
                    SequentialAnimation {
                        id: hexAnim
                        onFinished: revealModule.cellDone()
                        PauseAnimation { duration: hexCell.modelData.delay }
                        NumberAnimation { target: hexCell; property: "scale"; from: 1; to: 0; duration: 320; easing.type: Easing.InCubic }
                    }
                }
            }

            Repeater {
                id: blindsRepeater
                model: 0

                Rectangle {
                    id: blind
                    required property int modelData
                    visible: revealModule.activeKind === "blinds"
                    readonly property real stripW: stage.width / revealModule.blindCount
                    x: modelData * stripW
                    y: 0
                    width: stripW + 1
                    height: stage.height
                    color: Colors.background

                    function trigger() { blindAnim.restart() }

                    transform: Scale {
                        id: blindScale
                        origin.x: blind.width / 2
                        origin.y: blind.modelData % 2 === 0 ? 0 : blind.height
                        yScale: 1
                    }

                    SequentialAnimation {
                        id: blindAnim
                        onFinished: revealModule.cellDone()
                        PauseAnimation { duration: blind.modelData * 28 }
                        NumberAnimation { target: blindScale; property: "yScale"; from: 1; to: 0; duration: 380; easing.type: Easing.InOutCubic }
                    }
                }
            }
        }

        Connections {
            target: Wallpaper
            function onSourceChanged() { stage.beginTransition() }
        }

        Component.onCompleted: {
            stage.prevSource = Wallpaper.source;
            bgNew.opacity = 1;
        }
    }
}
