# Shell debt report

Scope: full read-only pass over `.config/quickshell/helios/` (117 QML files across `components/`, `modules/`, `services/`, and `shell.qml`), checked against import modernity, Quickshell windowing primitives, service/UI separation, and startup memory footprint.

## Executive summary

The repo does not have the legacy debt this kind of audit usually finds. No versioned Qt imports, no `Qt5Compat` usage, no manual `x`/`y` window positioning, every backend wrapped in a singleton service, and every infinite animation gated on a `running` condition tied to visibility or state. Risk level: low. This is closer to "keep doing what you're doing" than a remediation list.

Specifics below, by pillar, with what I actually found rather than what the audit brief assumed I'd find.

## Pillar A: imports

- Zero versioned imports anywhere (`grep -rn "^import Qt.*[0-9]\+\.[0-9]\+"` returns nothing). Every file already uses bare `import QtQuick`, `import QtQuick.Controls`, etc.
- Zero `Qt5Compat.*` imports. The one hit for "Qt5Compat" is a comment in `components/SurfaceShadow.qml:3` documenting that `QtQuick.Effects` (native Qt6) replaced it:
  ```qml
  import QtQuick.Effects  // Replacing Qt5Compat.GraphicalEffects
  ```
  Nothing to change here — this is the target state, not a leftover.
- `Quickshell`, `Quickshell.Wayland`, and `Quickshell.Hyprland` imports are consistent across the tree, no mixing with legacy X11-era assumptions.

## Pillar B: windowing

- Every top-level surface (`services/Bridge.qml`, `modules/bar/Bar.qml`, `modules/bar/SettingsWindow.qml`, `modules/bar/TrayMenu.qml`, `modules/osd/Osd.qml`, `modules/polkit/PolkitPrompt.qml`) is a `PanelWindow` with edge/anchor-based layout, not a plain `Window` with manual geometry.
- `modules/bar/TrayMenu.qml` correctly pairs its context menu with `PopupWindow`.
- No manual `x:`/`y:` window positioning anywhere in the tree. The few `mapToGlobal`/`mapToItem` calls (`Tray.qml`, `TrayMenuLevel.qml`, `LauncherIsland.qml`) are legitimate: they compute an anchor item's global rect to position a popup relative to a tray icon, which is the expected Quickshell pattern for popup anchoring, not a coordinate-tracking anti-pattern.
- `SettingsWindow.qml` uses `WlrLayershell.layer`, a namespace, and `exclusiveZone: -1` correctly, and masks its click-through region with `Region { item: card }`.

## Pillar C: service architecture

- Every system backend lives behind a singleton service in `services/` (34 files, all `pragma Singleton`): `Bluetooth`, `WifiNetworks`, `MediaSession`, `SystemStats`, `Notifications`, `Cava`, etc.
- UI files that import `Quickshell.Services.Pipewire` / `.UPower` directly (`VolumeIsland.qml`, `AudioMixerIsland.qml`, `PowerIsland.qml`, `StatusIndicators.qml`, `Osd.qml`) are doing the correct thing for Quickshell: those modules expose engine-level global objects (`Pipewire.nodes`, enums like `PwNodeType`), not something you instantiate — importing the module for type access isn't redundant backend instantiation.
- `services/MediaSessionCore.qml`, `BluetoothDeviceCore.qml`, and `NotificationCore.qml` are the three services without `pragma Singleton`, and that's correct: they're per-instance item delegates (one per media session / device / notification), not global state.
- No blocking JS found inside delegate bindings or render-path properties during this pass.

## Pillar D: lifecycle and memory

- `shell.qml` instantiates `SettingsWindow {}` eagerly, but the window itself stays unmapped (`visible: Bridge.settingsOpen && !Bridge.avatarPickerOpen`) and its actual page content is behind a `Loader` (`SettingsWindow.qml:326`) keyed on `selectedPage` — only the active settings page is ever instantiated, not all sixteen.
- Six files use `Loader`/`LazyLoader` for on-demand content: `TrayMenuLevel.qml`, `PanelWrapper.qml`, `SettingsWindow.qml`, `Bar.qml`, `Lock.qml`, `PolkitAgent.qml`. Bar islands load behind `Bar.qml:276`'s loader rather than all existing at once.
- Every `loops: Animation.Infinite` animation checked (`OrbitPanel`, `LoadingSpinner`, `RecordingDot`, `MediaCard`, `SystemMonitorIsland`, `Lock`, `ScreenRecorderIsland`) gates `running` on a live condition — `root.active`, `ScreenRecorder.recording`, `root.live`, `!Config.reducedMotion` — so nothing spins in the background when hidden or when reduced motion is on.

## Architectural redundancies

None found. No orphaned files, no duplicated layout math, no dead singletons.

## Prioritized action plan

Nothing critical or high-priority to fix. If you want a genuinely optional polish item:

- [ ] Minor: the `Qt5Compat` reference in `SurfaceShadow.qml:3` is just a comment — could reword to "previously used Qt5Compat.GraphicalEffects" so a future reader doesn't have to re-derive that it's historical context, not a live import. Not worth a dedicated pass on its own.

Everything else checked out clean against the four pillars.
