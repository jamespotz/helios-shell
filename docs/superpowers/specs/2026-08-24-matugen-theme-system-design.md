# Matugen-driven Material color system — design spec

Date: 2026-08-24
Status: approved for implementation planning

## Goal

Extend the existing wallpaper/theme pipeline (`Wallpaper.qml` → `Themes.qml` →
`Colors.qml`) so that:

1. Changing the wallpaper automatically regenerates the dynamic theme (today
   it requires manually re-clicking "Dynamic").
2. The dynamic theme can be generated with any of matugen's 9 Material
   scheme variants (`scheme-tonal-spot`, `scheme-vibrant`, `scheme-expressive`,
   `scheme-fruit-salad`, `scheme-rainbow`, `scheme-content`, `scheme-fidelity`,
   `scheme-monochrome`, `scheme-neutral`), selectable and persisted.
3. Dynamic mode supports a dark/light toggle without spawning matugen twice.
4. `Colors.qml` exposes the full Material role set (background/surface/
   primary/secondary/tertiary families + on-* + containers + outline/shadow)
   as a semantic QML API, in addition to (not instead of) the existing legacy
   properties every current component already binds to.
5. Failures leave the previous valid theme in place; rapid wallpaper/scheme
   switching doesn't pile up matugen processes.

## Non-goals

- No rewrite of the system-app theming (GTK/KDE/Ghostty/btop/nvim/zed/bat/
  Firefox/Hyprland) in `Themes.qml` — it keeps consuming the same legacy
  11-key palette shape it already does today (`writeSystemTheme(palette)`),
  unchanged.
- No replacement of the wallpaper reveal-animation system
  (`modules/wallpaper/Wallpaper.qml`) — untouched.
- No migration of existing consumers off the 11 legacy `Colors.*`
  properties. New Material-role properties are additive.
- No live-generated per-scheme preview swatches (would require running
  matugen once per scheme per wallpaper change) — static representative
  swatch hints only.

## Confirmed facts (verified against the live system)

- `matugen` 4.2.0 is installed at `/usr/bin/matugen`.
- `matugen image <path> -t <scheme-type> -j hex --dry-run --prefer saturation`
  (no `-m` needed) returns, per color role, **both** `"light"` and `"dark"`
  sub-objects with a `"color"` hex string, in one process call — confirmed by
  running it against a real image and inspecting the `colors` object.
- The `colors` object in matugen's JSON output includes (among others) every
  role needed for the requested semantic API:
  `background, on_background, surface, on_surface, surface_variant,
  on_surface_variant, surface_container, surface_container_low,
  surface_container_high, primary, on_primary, primary_container,
  on_primary_container, secondary, on_secondary, secondary_container,
  on_secondary_container, tertiary, on_tertiary, tertiary_container,
  on_tertiary_container, error, on_error, outline, shadow`.
- `-t/--type` accepts exactly: `scheme-content, scheme-expressive,
  scheme-fidelity, scheme-fruit-salad, scheme-monochrome, scheme-neutral,
  scheme-rainbow, scheme-tonal-spot, scheme-vibrant` (plus `scheme-smart`,
  unused here).
- `Process` args in Quickshell/Qt are passed as argv elements, not through a
  shell — wallpaper paths containing spaces are already safe today and
  remain safe (no `sh -c` is introduced anywhere in this design).

## Architecture

```
Wallpaper.qml (service)
      │  setPath() persists + (if Themes.mode === "dynamic") triggers regen
      ▼
Themes.qml (service)
      │  debounce timer → build matugen argv from {path, paletteScheme}
      ▼
matugen (external process, -j hex --dry-run)
      │  stdout: JSON with light+dark for every Material role
      ▼
Themes.qml: parse → cache {light, dark} full-role palettes → persist →
            pick active variant by dynamicDark → Colors.apply(palette)
      ▼
Colors.qml (singleton)
      │  legacy props (unchanged) + new Material-role props, each with
      │  Behavior ColorAnimation — components already bind directly to
      │  this singleton, so no shell restart is ever needed
      ▼
Quickshell components (Bar, panels, tabs, ThemeSettings, ...)
```

Responsibilities stay separated exactly as today:
- **Wallpaper management**: `Wallpaper.qml` (unchanged responsibility, one
  new call-out).
- **Palette generation**: `Themes.qml` (extended, still the only place that
  spawns matugen).
- **Settings persistence**: `theme.json` via `Themes.qml`'s existing
  `FileView`/`JsonAdapter` (extended with new fields), `wallpaper.json`
  unchanged.
- **QML color consumption**: `Colors.qml` (extended, still the only color
  singleton).

## Colors.qml changes

Add, alongside the existing 11 properties (all unchanged), the full Material
role set as new `color` properties, each with the same
`Behavior on <prop> { ColorAnimation { duration: 380; easing.type: Easing.OutCubic } }`
pattern already used:

```
background (existing) — kept as-is; onBackground is new
onBackground
surface (existing) — kept as-is
onSurface
surfaceVariant
onSurfaceVariant
surfaceContainer
surfaceContainerLow
surfaceContainerHigh
primary
onPrimary
primaryContainer
onPrimaryContainer
secondary
onSecondary
secondaryContainer
onSecondaryContainer
tertiary
onTertiary
tertiaryContainer
onTertiaryContainer
error
onError
outline
shadow
```

`apply(palette)` is extended to set all of the above from `palette`'s
matching camelCase keys, in addition to the existing 11 assignments.

Because the 12 hardcoded presets in `Themes.qml` only define the legacy
11 keys, a new pure helper in `Themes.qml`, `deriveFullPalette(base)`,
fills in the Material-role keys for presets deterministically:

- `primary = base.accent`, `onPrimary = base.accentText`
- `secondary = harmonize(base.accent, hue+40)`,
  `onSecondary = base.accentText`
- `tertiary = harmonize(base.accent, hue+200)`,
  `onTertiary = base.accentText`
- `*Container` variants = the corresponding base color's surface-adjacent
  neighbor (`primaryContainer = surfaceHigh` tinted toward accent is
  overkill; simplest correct approach: `xContainer = x`,
  `onXContainer = onX` — i.e. containers collapse to the same color as
  their base role for presets, since presets don't model the
  container/on-container contrast distinction). This keeps presets legible
  without inventing new preset data.
- `onBackground = text`, `onSurface = text`, `surfaceVariant = surfaceHigh`,
  `onSurfaceVariant = subtext`, `surfaceContainer = surface`,
  `surfaceContainerLow = background`, `surfaceContainerHigh = surfaceHigh`
- `error = danger`, `onError = accentText`, `outline = overlay`,
  `shadow = "#000000"`

For matugen-generated dynamic palettes, every role is taken directly from
matugen's own output — `deriveFullPalette` is not used there.

Both code paths converge on the same full palette shape before calling
`Colors.apply()`, so `Colors.apply()` itself has one uniform contract.

## Themes.qml changes

**Persistence (`theme.json` JsonAdapter)** — add:
```
property string paletteScheme: "scheme-tonal-spot"
property bool dynamicDark: true
property string dynamicPaletteLight: ""   // JSON-stringified full palette
property string dynamicPaletteDark: ""    // JSON-stringified full palette
```
`dynamicPalette` (the old single-variant field) is replaced by the two
above; `restoreFromSettings()` is updated to apply
`dynamicDark ? dynamicPaletteDark : dynamicPaletteLight` when
`mode === "dynamic"`, falling back to `presets.helios` on parse failure
exactly as today.

**New/changed functions:**

- `setPaletteScheme(name)`: persists `paletteScheme`, and if
  `mode === "dynamic"`, calls `applyDynamic()` (debounced — see below).
- `setDynamicMode(isDark)`: persists `dynamicDark`. If `mode === "dynamic"`
  and both cached variants are present, applies the requested variant from
  cache immediately (no process spawn — this is the "toggle is basically
  free" optimization enabled by matugen returning both variants per call).
  If a cache is missing (e.g. first ever dynamic generation, or the cache
  predates this feature), falls through to `applyDynamic()`.
- `applyDynamic()`: unchanged trigger surface (still what the UI/IPC call),
  but now goes through the debounce timer instead of spawning immediately.
- New `regenerateTimer: Timer { interval: 200; repeat: false;
  onTriggered: root.runMatugen() }` — `applyDynamic()` becomes "validate
  wallpaper path is set, then `regenerateTimer.restart()`". Any call to
  `applyDynamic()` while a timer is already pending simply restarts the
  200ms window, so bursts of wallpaper-picker clicks or scheme-chip clicks
  collapse into one matugen run.
- `runMatugen()` (renamed/extracted from the current inline body of
  `applyDynamic()`): builds
  `["matugen", "image", img, "-t", root.paletteScheme, "-j", "hex",
  "--dry-run", "--prefer", "saturation"]`, spawns via the existing
  `matugenProc.running = false; matugenProc.running = true` restart idiom
  (which already kills any prior instance — this plus the debounce timer
  covers "robust against rapid wallpaper switching").
- `matugenProc`'s `stdout.onStreamFinished` handler is extended to parse
  **both** `light` and `dark` for every role listed above into two full
  palette objects, `paletteLight` and `paletteDark`. On success: persist
  both as JSON strings, persist `mode = "dynamic"`, apply
  `dynamicDark ? paletteDark : paletteLight` via `Colors.apply()`, and run
  `writeSystemTheme()` with that same active variant (system-app theming
  keeps using the legacy 11-key subset of whichever variant is active,
  unchanged shape).
- On any failure path (JSON parse error, non-zero exit, empty stderr
  captured as error) — unchanged behavior: set `lastError`, do **not**
  touch `Colors`, `dynamicPaletteLight/Dark`, or `mode`. The previously
  applied palette (already live in `Colors`) simply stays displayed. This
  is already how today's code behaves for the JSON-parse-failure case; the
  same guarantee is preserved for the new code paths.

## Wallpaper.qml change

`setPath(text)` gets one addition after the existing persistence:

```js
function setPath(text) {
    settingsAdapter.path = text.trim();
    root.settingsFile.writeAdapter();
    if (Themes.mode === "dynamic") Themes.applyDynamic();
}
```

(`Themes` becomes a new import dependency of `Wallpaper.qml`; both are
`services` singletons already registered in the same `qmldir`, so this is a
same-module reference, consistent with how `Themes.qml` already imports
other `services` siblings.)

## UI changes — `ThemeSettings.qml`

Below the existing preset grid and "Dynamic (from wallpaper)" button, add:

1. A **scheme picker**: `Flow` of 9 chips (same visual pattern as the
   reveal-style chips in `WallpaperSettings.qml`), one per scheme, labeled
   with the human names from the spec (`"Tonal Spot"`, `"Vibrant"`, ...),
   internally mapped to `scheme-*` matugen type strings via a
   `readonly property var schemeOptions` list of `{label, value}` living in
   `Themes.qml` (so the mapping is centralized, not hardcoded twice). Each
   chip calls `Themes.setPaletteScheme(option.value)`; active chip
   highlighted via `Themes.paletteScheme === option.value`. Chips render at
   full opacity/interactive always, but only cause an actual regeneration
   effect visibly once the user is in dynamic mode (selecting a scheme
   while on a static preset just changes the pending selection for next
   time Dynamic is used — no surprise regen of a palette that isn't
   showing).
2. A small static **swatch dot** per chip: not matugen-generated (would be
   9 extra processes per open of the panel or per wallpaper change) — a
   fixed representative `Qt.hsla(...)` color per scheme type baked into
   `schemeOptions` (e.g. Monochrome → desaturated grey, Vibrant → high
   chroma, Rainbow → a small multi-hue gradient of 3 dots instead of 1),
   purely to hint at character.
3. A **dark/light Toggle** (reusing `components/Toggle.qml`), bound to
   `Themes.dynamicDark`, calling `Themes.setDynamicMode(checked)`.

No new QML component file is introduced — this extends the existing panel,
matching "integrate the selector there" from the requirements.

## Fruit Salad / accent-family usage

Small, targeted changes (accent-color binding only, no layout changes) in
the 5 files identified as using `Colors.accent` for non-"main control"
purposes:

- `modules/bar/NotifyCard.qml`: `Colors.accent` → `Colors.tertiary`
  (notifications/miscellaneous highlight).
- `modules/bar/BluetoothTab.qml`, `modules/bar/WifiTab.qml`:
  `Colors.accent` → `Colors.secondary` (connectivity controls).
- `modules/bar/MediaCard.qml`, `modules/bar/VolumeTab.qml`: unchanged,
  stay on `Colors.primary`/`Colors.accent` (main active controls).

Because presets also derive `secondary`/`tertiary` (see
`deriveFullPalette` above), these components keep looking correct outside
of fruit-salad/dynamic mode too — `secondary`/`tertiary` are never
undefined.

## Data flow summary / race conditions addressed

- **Rapid wallpaper switching**: `regenerateTimer` debounce (200ms) +
  existing `running=false;running=true` kill-and-restart idiom on
  `matugenProc` — only the last requested wallpaper/scheme combination
  within any 200ms window actually spawns matugen.
- **Scheme switch while a generation is in flight**: same debounce path —
  changing `paletteScheme` mid-flight just restarts the timer; the
  in-flight process's result, if it lands, is still parsed but the
  subsequent restart supersedes it once its own timer fires (matugenProc's
  restart kills the stale one before that happens in practice, since the
  timer restart re-triggers `runMatugen()` which re-toggles `running`).
- **Dark/light toggle**: no process spawn at all when a valid cache for
  both variants exists — eliminates an entire race class (toggling
  quickly between dark/light can never pile up matugen processes because
  it doesn't start any).
- **Matugen failure**: verified today's contract (only `lastError` is set;
  `Colors` and persisted palette untouched) and preserved in the extended
  parse logic.
- **Startup**: `Component.onCompleted: root.restoreFromSettings()` and the
  `settingsFile.onLoaded` re-run both already exist to handle the
  known Quickshell `JsonAdapter` load-order quirk (documented in the
  existing code's comment) — `restoreFromSettings()` is extended to read
  `dynamicPaletteDark`/`dynamicPaletteLight` per `dynamicDark`, same
  mechanism, no new race introduced.

## Files touched

- `.config/quickshell/helios/services/Colors.qml` — add Material-role
  properties + Behaviors; extend `apply()`.
- `.config/quickshell/helios/services/Themes.qml` — scheme list/options,
  full-role parsing, dual light/dark caching, debounce timer,
  `setPaletteScheme`/`setDynamicMode`, `deriveFullPalette`, persistence
  field changes.
- `.config/quickshell/helios/services/Wallpaper.qml` — one-line hook in
  `setPath()`.
- `.config/quickshell/helios/modules/bar/ThemeSettings.qml` — scheme
  picker chips + swatches + dark/light toggle.
- `.config/quickshell/helios/modules/bar/NotifyCard.qml`,
  `BluetoothTab.qml`, `WifiTab.qml` — accent → secondary/tertiary swaps.

No other files change. No new files are introduced (the scheme
picker reuses the existing panel and existing `components/Toggle.qml`).

## Validation plan

Manual, against a running Quickshell session (`link.sh`/existing dev
workflow), covering exactly the 8 scenarios from the requirements:

1. Start with an existing wallpaper → confirm `Colors` populates fully
   (legacy + Material roles) with no console warnings about undefined
   properties.
2. Change wallpaper while in dynamic mode → confirm matugen re-runs once
   (check via `Themes.generating` flicker / process count) and UI
   crossfades.
3. Tonal Spot → Fruit Salad → confirm `NotifyCard`/`BluetoothTab`/`WifiTab`
   visibly pick up a distinct secondary/tertiary hue from primary.
4. Fruit Salad → Monochrome → confirm all accent-family roles collapse
   toward greyscale together (no leftover colored role).
5. Toggle dark/light in dynamic mode → confirm instant switch (no
   "Generating…" flash, no new matugen process).
6. Restart Quickshell → confirm `paletteScheme`/`dynamicDark`/mode all
   restored from `theme.json`.
7. Point wallpaper at a path containing spaces → confirm matugen still
   runs correctly (argv-based `Process`, already safe).
8. Temporarily rename/hide `matugen` off PATH (or force a bad path) →
   confirm `lastError` is set, previous palette remains applied, and the
   panel doesn't crash.

Existing pitfall already present and worth calling out (not changed by
this work, but relevant to the persistence flow this design extends): the
`JsonAdapter` load-order quirk documented in `Themes.qml`'s own comment
above `restoreFromSettings()` — `Component.onCompleted` alone races the
adapter's async populate, which is why `restoreFromSettings()` must also
run from `settingsFile.onLoaded`. The new fields follow the same pattern
already in place, so no new instance of this pitfall is introduced, but a
future editor removing the `onLoaded` hook would silently reintroduce it
for the new fields too.
