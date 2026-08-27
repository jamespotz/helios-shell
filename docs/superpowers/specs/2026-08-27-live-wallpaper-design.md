# Live (video) wallpaper support — design

## Goal

Let `Wallpaper.path` point at a video file (mp4/webm/mkv/mov) as well as a
static image, and have it play back silently, looping, per screen — while
staying inside the shell's existing per-screen `PanelWindow` wallpaper
architecture rather than introducing an external player process.

Scope: video files only (no GIF/animated-image or shader-driven wallpaper
support — those were considered and explicitly deferred, see "Out of scope").

## Playback engine

Qt6 Multimedia's QML module (`MediaPlayer` + `VideoOutput`) is used
in-process, one instance per screen, rather than an external `mpv`/
`mpvpaper` process per screen. It renders directly inside the same
`PanelWindow`/`WlrLayershell.layer: Background` surface each screen already
has, with no subprocess lifecycle or layer-shell embedding trick to manage.
Trade-off: codec support is whatever Qt's backend (ffmpeg on this system)
provides, not mpv's broader format/hardware-decode tuning — acceptable for
personal wallpaper video files.

Each screen decodes independently (its own `MediaPlayer`/`VideoOutput`, all
pointed at the same file path, started independently rather than
frame-synced). This is the simplest fit for the existing one-`PanelWindow`-
per-screen model. Cost scales with screen count; fine for this machine's
setup, would need revisiting for a many-monitor rig.

Audio is never attached (`audioOutput: null`) — wallpapers are silent by
construction, not just muted.

## Data model (`services/Wallpaper.qml`)

No new path field. A single derived property distinguishes video from
image, keeping `path`/`folderPath`/`setPath()`/`setFolder()` and the
JSON-persisted settings file exactly as they are today:

```qml
readonly property bool isVideo: {
    const ext = root.path.split(".").pop().toLowerCase();
    return ["mp4", "webm", "mkv", "mov"].includes(ext);
}
```

`scanFolder()`'s `find` regex is extended to also match those four
extensions alongside the existing image ones, so video files show up in the
same folder scan and thumbnail grid as images.

`Themes.applyDynamic()` (matugen-driven dynamic theming) gets one guard: if
`Wallpaper.isVideo`, return early without invoking matugen — matugen reads
still images, not video, and extracting a frame via ffmpeg first is more
machinery than this feature justifies. Dynamic theme mode simply keeps
whatever palette was last generated while a video wallpaper is active.

## Rendering (`modules/wallpaper/Wallpaper.qml`)

Each screen's `stage` gains a `MediaPlayer` + `VideoOutput` pair occupying
the same z:1 slot `bgNew` (the `Image`) currently occupies:

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

`bgNew` becomes `visible: !Wallpaper.isVideo` so exactly one of the two
occupies z:1 at a time. `driftAnim` (the slow breathing scale animation on
resting wallpapers) is additionally gated `&& !Wallpaper.isVideo` — a video
doesn't need the synthetic "living" touch.

### Transitions

The existing modular reveal system (`blur`, `glitch`, `liquid`, `grid`,
`neon`, `honeycomb`, `blinds`) stays untouched for image→image switches.
Most of those styles depend on slicing or masking a static `Image` of the
new source (`grid` alone instantiates ~96 independent `Image` copies) and
don't translate to a single video decode.

When either side of a wallpaper switch `isVideo`, `playTransition()` skips
`pickStyle()` and runs only the existing `fadeOld` opacity crossfade.
`beginTransition()` captures a still for `bgOld` via `bgVideo.grabToImage()`
immediately before switching (rather than leaving `bgOld` blank), so the
crossfade always fades from a real frame regardless of which side is video.

### Power/lock gating

Playback is gated by a new computed property:

```qml
readonly property bool videoShouldPlay: Wallpaper.isVideo && !Bridge.locked && !UPower.onBattery
```

`UPower.onBattery` already exists (`Quickshell.Services.UPower`, used
elsewhere in the shell for the battery indicator). `Bridge.locked` is new —
`services/Bridge.qml` gains `property bool locked: false`, set by
`modules/lock/Lock.qml`'s `Loader.onActiveChanged` handler
(`Bridge.locked = active`). Nothing currently exposes lock state outside
the Lock module itself; this follows the same single-source-of-truth
pattern `Bridge.lockRequested()` already establishes for the reverse
direction.

## Settings UI (`modules/bar/WallpaperSettings.qml`)

**Hero preview:** when `Wallpaper.isVideo`, the preview `Rectangle` shows
the same `MediaPlayer`+`VideoOutput` pattern (playing, muted) instead of an
`Image`, so the settings panel itself previews motion.

**Thumbnail grid:** video files get no decoded-frame thumbnail — no
ffmpeg-thumbnail-extraction pipeline is being added for this. A video tile
renders as a flat `Colors.surfaceHigh` tile with a centered
`MaterialIcon { icon: "movie" }` and the filename below, using the same
selection/hover/glow chrome the image tiles already have.

**Reveal-style chips:** unchanged. They remain inert (no visible effect)
when a video wallpaper is involved, per the transitions section above —
worth a one-line code comment, not a UI change.

## Out of scope

- GIF/animated-image wallpapers.
- Shader/procedural (generative) backgrounds.
- Video thumbnail extraction for the picker grid.
- Cross-screen frame synchronization (each screen's decode starts and
  drifts independently).
- Any external player process (mpv/mpvpaper).

## Testing

No automated test suite exists for this shell — it's a live-reloading QML
config (per AGENTS.md/`qmldir`, changes apply on save). Verification is
manual:

1. Set a video wallpaper via the picker; confirm it loops silently and the
   crossfade plays on switch-in.
2. Lock the session (`Bridge.lock()`/hyprlock trigger); confirm playback
   pauses — check via `hyprctl`/process CPU, not just visually.
3. Force `UPower.onBattery` (unplug AC, or temporarily stub the property);
   confirm playback pauses the same way, and resumes on AC.
4. Switch from a video wallpaper back to an image; confirm the full
   7-style reveal system still plays normally, untouched.
5. Confirm dynamic theme mode does not attempt to regenerate (no matugen
   process spawned) while a video wallpaper is active.
