# Live (Video) Wallpaper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let `Wallpaper.path` point at a video file (mp4/webm/mkv/mov) that plays back silently and looping, per screen, inside the existing wallpaper layer-shell architecture.

**Architecture:** Qt6 Multimedia (`MediaPlayer` + `VideoOutput`) rendered in-process inside each screen's existing `PanelWindow`, alongside the current `Image`-based static wallpaper. A single `Wallpaper.path` drives both image and video (auto-detected by extension); no new config fields.

**Tech Stack:** QML, Qt6 Multimedia (`QtMultimedia` import), Quickshell (`Quickshell.Services.UPower`, `Quickshell.Wayland`).

**Spec:** `docs/superpowers/specs/2026-08-27-live-wallpaper-design.md`

## Global Constraints

- Video detection is by file extension only: `mp4`, `webm`, `mkv`, `mov` (spec: "Data model").
- No `AudioOutput` is ever attached to the `MediaPlayer` — silent by construction, not muted (spec: "Playback engine").
- Each screen decodes independently; no cross-screen frame sync (spec: "Playback engine").
- Video↔anything transitions use only the existing `fadeOld` crossfade — never `pickStyle()`'s 7-style system (spec: "Transitions").
- Video playback pauses when `Bridge.locked` or `UPower.onBattery` is true (spec: "Power/lock gating").
- No thumbnail-extraction pipeline for video files in the picker grid — icon placeholder only (spec: "Settings UI").
- No automated test suite exists in this repo; every task's verification is manual, against the running shell (which auto-reloads QML on save).

---

### Task 1: Expose session-lock state on `Bridge`

**Files:**
- Modify: `.config/quickshell/helios/services/Bridge.qml`
- Modify: `.config/quickshell/helios/modules/lock/Lock.qml`

**Interfaces:**
- Produces: `Bridge.locked` (bool, read from anywhere via the `services` singleton import) — true whenever the lock screen `Loader` is active.

- [ ] **Step 1: Add the property to Bridge**

In `services/Bridge.qml`, add alongside the other top-level properties (near `trayMenuOpen` etc.):

```qml
    property bool locked: false
```

- [ ] **Step 2: Set it from Lock.qml's Loader**

In `modules/lock/Lock.qml`, the top-level `Loader { id: root; active: false ... }` needs an `onActiveChanged` handler. Add it directly under `active: false`:

```qml
Loader {
    id: root
    active: false
    onActiveChanged: Bridge.locked = active

    Connections {
        target: Bridge
        function onLockRequested() { root.active = true }
    }
```

- [ ] **Step 3: Manual verification**

Run the shell (or let it live-reload), trigger the lock via whatever binds to `Bridge.lock()` (e.g. `quickshell -c helios ipc call lock lock`), and confirm no QML errors in the shell's log output. Add a temporary `onLockedChanged: console.log("Bridge.locked:", locked)` in `Bridge.qml`, watch the log while locking/unlocking, then remove the temporary log line.

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/helios/services/Bridge.qml .config/quickshell/helios/modules/lock/Lock.qml
git commit -m "Expose Bridge.locked for session-lock state"
```

---

### Task 2: `Wallpaper.isVideo` + extend folder scan to video files

**Files:**
- Modify: `.config/quickshell/helios/services/Wallpaper.qml`

**Interfaces:**
- Consumes: none (self-contained).
- Produces: `Wallpaper.isVideo` (readonly bool) — used by Task 3 (Themes), Task 4/5 (rendering module), Task 6/7 (settings UI).

- [ ] **Step 1: Add `isVideo`**

In `services/Wallpaper.qml`, add directly under the existing `source` property:

```qml
    readonly property bool isVideo: {
        const ext = root.path.split(".").pop().toLowerCase();
        return ["mp4", "webm", "mkv", "mov"].includes(ext);
    }
```

- [ ] **Step 2: Extend the folder scan regex**

In `scanFolder()`, the `find` command currently matches only image extensions:

```qml
        folderScanner.command = ["sh", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \\) 2>/dev/null | sort',
            "sh", dir];
```

Change it to also match the four video extensions:

```qml
        folderScanner.command = ["sh", "-c",
            'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" -o -iname "*.mov" \\) 2>/dev/null | sort',
            "sh", dir];
```

- [ ] **Step 3: Manual verification**

Put a small `.mp4` file in the wallpaper folder Config points at (or a test folder), trigger a rescan (`Wallpaper.scanFolder()` — e.g. reopen the folder editor and hit Scan), and confirm `Wallpaper.images` includes the video's path. Temporarily bind `Wallpaper.setPath()` to that path and confirm `Wallpaper.isVideo` is `true` (add a throwaway `console.log(Wallpaper.isVideo)` binding, check, remove it).

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/helios/services/Wallpaper.qml
git commit -m "Add Wallpaper.isVideo and include video files in folder scan"
```

---

### Task 3: Skip matugen dynamic theming for video wallpapers

**Files:**
- Modify: `.config/quickshell/helios/services/Themes.qml`

**Interfaces:**
- Consumes: `Wallpaper.isVideo` (Task 2).

- [ ] **Step 1: Guard `applyDynamic()`**

In `services/Themes.qml`, `applyDynamic()` currently starts with:

```qml
    function applyDynamic() {
        if (!Wallpaper.path) { root.lastError = "Set a wallpaper first"; return; }
```

Add a second guard right after it:

```qml
    function applyDynamic() {
        if (!Wallpaper.path) { root.lastError = "Set a wallpaper first"; return; }
        if (Wallpaper.isVideo) { return; }
```

No error is set for the video case — this isn't a failure, it's an inert no-op while a video wallpaper is active, matching the spec's "keeps whatever palette was last generated."

- [ ] **Step 2: Manual verification**

With `Themes.mode === "dynamic"`, set a video wallpaper via `Wallpaper.setPath()` and confirm (via the shell's log, or a temporary log line in `matugenProc`'s `running` setter) that no `matugen` process is spawned. Then set an image wallpaper again and confirm matugen still runs as before.

- [ ] **Step 3: Commit**

```bash
git add .config/quickshell/helios/services/Themes.qml
git commit -m "Skip matugen dynamic theming while a video wallpaper is active"
```

---

### Task 4: Render video wallpapers per screen

**Files:**
- Modify: `.config/quickshell/helios/modules/wallpaper/Wallpaper.qml`

**Interfaces:**
- Consumes: `Wallpaper.isVideo`, `Wallpaper.source` (Task 2), `Bridge.locked` (Task 1), `UPower.onBattery` (existing, `Quickshell.Services.UPower`).
- Produces: `stage.videoShouldPlay` (readonly bool) — consumed by Task 5's transition logic only indirectly (it reads `Wallpaper.isVideo` directly); this property is otherwise self-contained to this file.

- [ ] **Step 1: Add the UPower import**

At the top of `modules/wallpaper/Wallpaper.qml`, add alongside the existing imports:

```qml
import Quickshell.Services.UPower
```

- [ ] **Step 2: Add `videoShouldPlay` and the MediaPlayer/VideoOutput pair**

Inside `Item { id: stage ... }`, add after the `allStyles` property block (near the other core-state properties):

```qml
        readonly property bool videoShouldPlay: Wallpaper.isVideo && !Bridge.locked && !UPower.onBattery
```

Add the player and output right after the `bgNew` `Image` block (still inside `stage`):

```qml
        MediaPlayer {
            id: videoPlayer
            source: Wallpaper.isVideo ? Wallpaper.source : ""
            loops: MediaPlayer.Infinite
            audioOutput: null
            playbackState: stage.videoShouldPlay ? MediaPlayer.PlayingState : MediaPlayer.PausedState
        }

        VideoOutput {
            id: bgVideo
            anchors.fill: parent
            visible: Wallpaper.isVideo
            z: 1
            source: videoPlayer
            fillMode: VideoOutput.PreserveAspectCrop
        }
```

Add the `QtMultimedia` import at the top of the file alongside the others:

```qml
import QtMultimedia
```

- [ ] **Step 3: Make `bgNew` yield to video, and gate the drift animation**

Change `bgNew`'s `visible` binding from:

```qml
            visible: source !== "" && status === Image.Ready
```

to:

```qml
            visible: !Wallpaper.isVideo && source !== "" && status === Image.Ready
```

Change `driftAnim`'s `running` binding from:

```qml
            running: !stage.awaitingReady && !stage.transitioning && bgNew.status === Image.Ready
```

to:

```qml
            running: !Wallpaper.isVideo && !stage.awaitingReady && !stage.transitioning && bgNew.status === Image.Ready
```

- [ ] **Step 4: Manual verification**

Set a video wallpaper (`Wallpaper.setPath()` to the test `.mp4` from Task 2). Confirm on-screen: the video plays, loops, and is silent. Lock the session and confirm the video freezes (via `hyprctl` CPU usage on the shell process dropping, or the on-screen frame visibly stopping). Unlock and confirm it resumes. If you can toggle `UPower.onBattery` (unplug AC, or on a desktop temporarily hack `playbackState` to test the false branch), confirm the same pause/resume behavior.

- [ ] **Step 5: Commit**

```bash
git add .config/quickshell/helios/modules/wallpaper/Wallpaper.qml
git commit -m "Render video wallpapers via Qt Multimedia, gated by lock/battery state"
```

---

### Task 5: Crossfade-only transitions when video is involved

**Files:**
- Modify: `.config/quickshell/helios/modules/wallpaper/Wallpaper.qml`

**Interfaces:**
- Consumes: `Wallpaper.isVideo`, `bgVideo` (Task 4).
- Produces: none consumed by later tasks.

- [ ] **Step 1: Capture a still of the outgoing video before switching**

`beginTransition()` currently starts with:

```qml
        function beginTransition() {
            bgOld.source = stage.prevSource;
            bgOld.opacity = 1;
            stage.prevSource = Wallpaper.source;
```

The outgoing side may be a video, in which case `stage.prevSource` (a file path) is not a still frame `bgOld` (an `Image`) can show directly. Change it to grab a still when the outgoing side was video, before overwriting `bgOld.source`:

```qml
        function beginTransition() {
            if (bgVideo.visible) {
                bgVideo.grabToImage(function(result) { bgOld.source = result.url; });
            } else {
                bgOld.source = stage.prevSource;
            }
            bgOld.opacity = 1;
            stage.prevSource = Wallpaper.source;
```

`grabToImage`'s callback is async (fires on the next frame), which is fine here — `bgOld.opacity = 1` and the rest of the transition setup don't depend on `bgOld.source` having updated synchronously; `fadeOld` only needs `bgOld` to have *some* correct-ish content by the time it's visibly fading, and grabs complete well within a frame or two.

- [ ] **Step 2: Skip `pickStyle()` for any switch involving video**

`playTransition()` currently always calls `stage.pickStyle()`:

```qml
        function playTransition() {
            stage.awaitingReady = false;
            stage.transitioning = true;
            fadeOld.restart();

            switch (stage.pickStyle()) {
```

Add a video short-circuit right before the `switch`, using `stage.prevSource` (the path just switched away from, still available since `beginTransition()` doesn't clear it) and `Wallpaper.isVideo` (the incoming side) to decide:

```qml
        function playTransition() {
            stage.awaitingReady = false;
            stage.transitioning = true;
            fadeOld.restart();

            const prevWasVideo = ["mp4", "webm", "mkv", "mov"].includes(stage.prevSource.split(".").pop().toLowerCase());
            if (Wallpaper.isVideo || prevWasVideo) {
                stage.transitionFinished();
                return;
            }

            switch (stage.pickStyle()) {
```

`fadeOld` (the existing `bgOld` opacity-to-0 animation) already ran via `fadeOld.restart()` above, so this is genuinely "crossfade only" — the early return just skips layering one of the 7 reveal modules on top.

- [ ] **Step 3: Manual verification**

Switch from an image wallpaper to the test video: confirm the old image crossfades out smoothly (no reveal-style tiles/glitches on top) while the video fades in already playing. Switch from that video back to a different image: confirm the video's last frame crossfades to the new image the same way. Switch between two images (no video involved at all): confirm the full 7-style reveal system still plays exactly as before this task.

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/helios/modules/wallpaper/Wallpaper.qml
git commit -m "Use plain crossfade instead of reveal styles for video wallpaper switches"
```

---

### Task 6: Video preview in the settings hero panel

**Files:**
- Modify: `.config/quickshell/helios/modules/bar/WallpaperSettings.qml`

**Interfaces:**
- Consumes: `Wallpaper.isVideo`, `Wallpaper.path` (Task 2).

- [ ] **Step 1: Add the QtMultimedia import**

At the top of `modules/bar/WallpaperSettings.qml`:

```qml
import QtMultimedia
```

- [ ] **Step 2: Swap in a VideoOutput for the hero preview when video**

The hero preview currently has one `Image` inside the preview `Rectangle`:

```qml
            Image {
                anchors.fill: parent
                visible: Wallpaper.path !== ""
                source: Wallpaper.path !== "" ? "file://" + Wallpaper.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
```

Change its `visible` to exclude video, and add a video counterpart right after it (still inside the same preview `Rectangle`, before the `MaterialIcon` fallback):

```qml
            Image {
                anchors.fill: parent
                visible: Wallpaper.path !== "" && !Wallpaper.isVideo
                source: Wallpaper.path !== "" ? "file://" + Wallpaper.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            MediaPlayer {
                id: previewPlayer
                source: Wallpaper.isVideo ? Wallpaper.source : ""
                loops: MediaPlayer.Infinite
                audioOutput: null
                playbackState: Wallpaper.isVideo ? MediaPlayer.PlayingState : MediaPlayer.PausedState
            }

            VideoOutput {
                anchors.fill: parent
                visible: Wallpaper.isVideo
                source: previewPlayer
                fillMode: VideoOutput.PreserveAspectCrop
            }
```

The `MaterialIcon` fallback's `visible: Wallpaper.path === ""` and the filename overlay's `visible: Wallpaper.path !== ""` at the bottom of the preview both already work correctly for video paths unchanged — they key off `Wallpaper.path`, not the image specifically.

- [ ] **Step 3: Manual verification**

Open the wallpaper settings panel with the test video set as current; confirm the hero preview plays the video (looping, silent). Switch to an image wallpaper and confirm the preview goes back to a static image with no leftover video artifacts.

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/helios/modules/bar/WallpaperSettings.qml
git commit -m "Preview video wallpapers with playback in the settings hero panel"
```

---

### Task 7: Icon placeholder for video thumbnails in the picker grid

**Files:**
- Modify: `.config/quickshell/helios/modules/bar/WallpaperSettings.qml`

**Interfaces:**
- Consumes: `Wallpaper.images` (existing, now includes video paths per Task 2).

- [ ] **Step 1: Detect video by extension in the thumbnail delegate**

The thumbnail `Repeater`'s delegate `Item { id: thumb; required property string modelData; ... }` needs a local video check. Add it right after the existing `selected` property:

```qml
                        readonly property bool selected: Wallpaper.path === modelData
                        readonly property bool isVideoThumb: ["mp4", "webm", "mkv", "mov"].includes(modelData.split(".").pop().toLowerCase())
```

- [ ] **Step 2: Gate the existing image/mask block, add the placeholder**

The thumbnail currently always renders `mask` + `img` (`Image`) + `OpacityMask`. Gate all three on `!thumb.isVideoThumb`:

```qml
                        Rectangle {
                            id: mask
                            anchors.fill: parent
                            radius: Colors.radiusSmall
                            visible: false
                        }

                        Image {
                            id: img
                            anchors.fill: mask
                            source: "file://" + thumb.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: false
                            sourceSize: Qt.size(grid.cellWidth * 2, grid.cellHeight * 2)
                        }

                        OpacityMask {
                            anchors.fill: mask
                            source: img
                            maskSource: mask
                            visible: !thumb.isVideoThumb
                        }
```

(`mask`/`img` themselves stay `visible: false` regardless — only `OpacityMask`, which is what actually paints, needs the gate.)

Then add the placeholder as a sibling, right after the `OpacityMask` block:

```qml
                        Rectangle {
                            anchors.fill: parent
                            radius: Colors.radiusSmall
                            color: Colors.surfaceHigh
                            visible: thumb.isVideoThumb

                            MaterialIcon {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -8
                                icon: "movie"
                                font.pixelSize: 22
                                opacity: 0.6
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 6
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                font.pixelSize: Config.fontSize - 3
                                opacity: 0.7
                                text: thumb.modelData.split("/").pop()
                            }
                        }
```

The selection glow, border, check icon, hover overlay, and `MouseArea` below this block are all already keyed off `thumb.selected`/generic hover and need no changes — they layer on top of whichever of the two (image or placeholder) is visible.

- [ ] **Step 3: Manual verification**

With the test video in the scanned folder, open the picker grid and confirm its tile shows the movie icon + filename (not a broken image / blank tile), with the same selection ring and hover highlight as image tiles. Click it and confirm `Wallpaper.setPath()` fires and the hero preview updates per Task 6.

- [ ] **Step 4: Commit**

```bash
git add .config/quickshell/helios/modules/bar/WallpaperSettings.qml
git commit -m "Show icon placeholder for video files in the wallpaper thumbnail grid"
```

---

## Post-implementation full verification

Repeat the spec's 5-point manual test pass end-to-end after all 7 tasks land:

1. Set a video wallpaper via the picker; confirm loop + silent playback + crossfade-in.
2. Lock the session; confirm playback pauses (check CPU via `hyprctl`/`top`, not just visually).
3. Force `UPower.onBattery`; confirm playback pauses, resumes on AC.
4. Switch video → image; confirm the full 7-style reveal system still works.
5. Confirm no matugen process spawns while a video wallpaper is active in dynamic theme mode.
