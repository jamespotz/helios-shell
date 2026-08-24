# helios

A [Quickshell](https://quickshell.org)-based desktop shell for Hyprland, inspired by
[caelestia-dots/shell](https://github.com/caelestia-dots/shell). Built for Fedora 44.

The bar *is* a [Dynamic Island](https://github.com/mavxa/DynamicGlacier)-style widget:
a small, fully-rounded idle bump floating just below the true screen edge on each
screen, that morphs open — on hover for workspaces/clock/weather/tray/status,
automatically for notifications and playing media, or on click for the
volume/output (including mic input), Bluetooth, Wifi, clipboard-history (via
`cliphist`), or weather-location panel — instead of staying a fixed full-width pill.
Every idle-bump/expanded-island widget (workspaces, clock, weather, tray, clipboard,
status icons...) can be toggled independently from the island's own settings tab. Multiple pending notifications collapse into one grouped card
(count + a scrollable list + "Clear all") instead of stacking separate toasts. An
optional experimental Liquid Glass mode swaps the flat panel background for a real
Hyprland-blurred translucent surface. Also ships: a wallpaper (one background-layer
image per screen, cropped to fill), an app launcher that searches native, Flatpak,
*and* Snap apps, a volume/brightness OSD, a power menu, and a session lock screen —
all written from scratch in QML against Quickshell's native services (Hyprland IPC,
Pipewire, UPower, Bluez, NetworkManager, SystemTray, Mpris, Notifications,
DesktopEntries, Pam, wlr-layer-shell/session-lock), plus a direct `wttr.in` lookup
for weather. No Rust helper binaries, no AUR-only tooling.

## Dependencies

All required unless marked optional. Install commands are for Fedora 44 — anything
not in the official repos says so and gives the COPR/cargo fallback.

- `quickshell` (Wayland shell toolkit) — not in Fedora's official repos; install
  from the `lionheartp/Hyprland` COPR:
  `sudo dnf copr enable lionheartp/hyprland && sudo dnf install quickshell`
- Hyprland — official Fedora repo: `sudo dnf install hyprland`
- `brightnessctl` (brightness OSD) — official Fedora repo:
  `sudo dnf install brightnessctl`
- `cava` (drives the island's media visualizer; optional — the cover art still
  shows without it) — official Fedora repo: `sudo dnf install cava`
- `cliphist` + `wl-copy`/`wl-paste` (clipboard-history widget/tab — the shell reads/copies/deletes
  through your existing `wl-paste --watch cliphist store` setup, it doesn't watch the clipboard itself).
  `wl-clipboard` (for `wl-copy`/`wl-paste`) is in Fedora's official repos:
  `sudo dnf install wl-clipboard`. `cliphist` isn't — install from a COPR (e.g.
  `wef/cliphist`) or `go install go.senan.xyz/cliphist@latest`:
  `sudo dnf copr enable wef/cliphist && sudo dnf install cliphist`
- `matugen` (dynamic wallpaper-based theming) — not in Fedora's official repos;
  install from a COPR (e.g. `heus-sueh/packages`) or `cargo install matugen`:
  `sudo dnf copr enable heus-sueh/packages && sudo dnf install matugen`
- `bat` (only needed if you want the Bat theme kept in sync — everything else
  themes independently) — official Fedora repo: `sudo dnf install bat`

Changing the theme (preset or dynamic) also re-themes GTK, KDE/Qt, Ghostty, btop, Neovim
(regenerates `lua/matugen.lua` + signals any running instance, matching that file's existing
SIGUSR1 hot-reload hook), Zed, and Bat. Firefox gets a best-effort `userChrome.css`/`userContent.css`
+ pref — only for a native (non-Flatpak) default profile found via `~/.mozilla/firefox/profiles.ini`;
it's silently skipped if that file doesn't exist.
- The **Material Symbols Rounded** variable font, installed to
  `~/.local/share/fonts/MaterialSymbolsRounded.ttf` (see below if missing) — no
  Fedora package; fetched directly from Google's repo (command below)
- **Adwaita Sans** (`adwaita-sans-fonts`) for UI text — official Fedora repo,
  already on most Fedora installs: `sudo dnf install adwaita-sans-fonts`

If the icon font isn't already on your system:

```sh
mkdir -p ~/.local/share/fonts
curl -sL -o ~/.local/share/fonts/MaterialSymbolsRounded.ttf \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

## Install

This repo is a [GNU Stow](https://www.gnu.org/software/stow/) package — its layout
mirrors `$HOME` (`.config/quickshell/helios/...`).

```sh
git clone <this-repo> ~/Projects/qml-shell   # or wherever you keep it
cd ~/Projects/qml-shell
stow -t ~ .
```

This symlinks `~/.config/quickshell/helios` → `../Projects/qml-shell/.config/quickshell/helios`.
To uninstall: `stow -D -t ~ .` from the same directory.

## Running

The shell is *not* autostarted — it's meant to be tried alongside whatever's already
running (e.g. Noctalia) before you commit to it.

```sh
quickshell -c helios          # foreground
quickshell -c helios -d       # detach from terminal
```

To make it your daily driver, add to your Hyprland config's autostart/exec-once block:

```
exec-once = quickshell -c helios
```

(and remove/comment out whatever previously started your old bar).

## Keybinds

The shell exposes an IPC surface so Hyprland binds can drive the launcher, power menu,
lock screen, and OSD without needing a second process:

```
quickshell -c helios ipc call launcher toggle
quickshell -c helios ipc call lock lock
quickshell -c helios ipc call powermenu toggle
quickshell -c helios ipc call osd volumeUp / volumeDown / toggleMute
quickshell -c helios ipc call osd brightnessUp / brightnessDown
quickshell -c helios ipc call island toggle volume / bluetooth / wifi / media / clipboard / weather / wallpaper / theme / island
quickshell -c helios ipc call island close
quickshell -c helios ipc call island liquidGlass true / false
quickshell -c helios ipc call island appearance 132 26 8 13    # width height gap fontSize
quickshell -c helios ipc call island resetAppearance
quickshell -c helios ipc call weather location "Tokyo"    # or "lat,long"; empty string resets to IP auto-detect
quickshell -c helios ipc call wallpaper set "/path/to/image.jpg"    # empty string clears it
quickshell -c helios ipc call wallpaper folder "/path/to/folder"    # empty string clears it
quickshell -c helios ipc call theme apply "<preset name>"
quickshell -c helios ipc call theme dynamic    # regenerate the dynamic (matugen) palette from the current wallpaper
quickshell -c helios ipc call clipboard list    # prints the cached cliphist entries, one per line
quickshell -c helios ipc call clipboard refresh    # re-reads `cliphist list` before the next `list` call
```

If you use the same Lua-based Hyprland config as this machine (`utils.safe_load` from
`~/.config/hypr/hyprland.lua`), the binds already live in their own file —
`~/.config/hypr/helios-binds.lua` — loaded via one added line in `hyprland.lua`
(`utils.safe_load("helios-binds")`). It never touches the existing `binds.lua`. Every
bind there is a plain `hl.bind(<combo>, hl.dsp.exec_cmd(<command>), { description = "..." })`
call, e.g.:

```lua
local mainMod = "SUPER"
local helios = "quickshell -c helios ipc call"

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(helios .. " launcher toggle"),
  { description = "Toggle helios launcher" })
```

The full set, grouped the same way the file itself is:

| Bind | Action |
| --- | --- |
| **Core** | |
| `SUPER + SPACE` | Toggle launcher |
| `SUPER + L` | Lock screen |
| `SUPER + ESCAPE` | Toggle power menu |
| `SUPER + K` | Toggle keybind cheatsheet |
| **OSD / brightness** | |
| `SUPER + ALT + Up` / `Down` | Brightness up/down (shows the helios OSD; repeats while held) |
| **Island tabs** (same combo again closes it) | |
| `SUPER + ALT + V` | Toggle clipboard history island |
| `SUPER + ALT + B` | Toggle Bluetooth island |
| `SUPER + ALT + N` | Toggle network (Wifi) island |
| `SUPER + ALT + M` | Toggle media player island |
| `SUPER + ALT + W` | Toggle weather island |
| `SUPER + ALT + A` | Toggle activity island |
| `SUPER + ALT + P` | Toggle wallpaper picker island |
| `SUPER + ALT + T` | Toggle theme picker island |
| `SUPER + ALT + I` | Toggle island settings island |
| `SUPER + ALT + ESCAPE` | Close island panel, whatever tab is open |
| **Instant actions** (fires once, no panel) | |
| `SUPER + SHIFT + T` | Apply dynamic theme from current wallpaper |
| `SUPER + SHIFT + V` | Refresh clipboard history |
| `SUPER + SHIFT + R` | Reload/relaunch helios (kills and restarts the `quickshell -c helios` process — see below) |

Volume keys are left as-is (already bound to `wpctl` in `binds.lua`) — helios's OSD
watches Pipewire directly and pops up on any volume/mute change regardless of what
triggered it, so no rebind was needed there. The existing `XF86MonBrightness*` binds
call `brightnessctl` directly and won't show the OSD (it isn't watched passively);
the `SUPER + ALT + Up/Down` pair above is the equivalent that does.

Everything except reload goes through `quickshell -c helios ipc call ...` — that only
works while helios is already running and responsive. Reload/relaunch (`SUPER + SHIFT + R`)
deliberately goes around IPC instead, straight through a shell:

```lua
hl.bind(mainMod .. " + SHIFT + R",
  hl.dsp.exec_cmd("pkill -f 'quickshell -c helios'; quickshell -c helios -d"),
  { description = "Reload/relaunch helios" })
```

`pkill` failing when nothing's running yet is fine — `;` (not `&&`) still runs the
relaunch either way, and `quickshell -c helios -d` detaches on its own so the bind
doesn't block. Use it after a crash, or after any change that a QML hot-reload alone
doesn't pick up.

If you're on a plain `hyprland.conf`, the equivalent entries are:

```
bind = SUPER, SPACE, exec, quickshell -c helios ipc call launcher toggle
bind = SUPER, L, exec, quickshell -c helios ipc call lock lock
bind = SUPER, ESCAPE, exec, quickshell -c helios ipc call powermenu toggle
bind = SUPER ALT, Up, exec, quickshell -c helios ipc call osd brightnessUp
bind = SUPER ALT, Down, exec, quickshell -c helios ipc call osd brightnessDown
bind = SUPER SHIFT, R, exec, pkill -f 'quickshell -c helios'; quickshell -c helios -d
```

## Layout

```
.config/quickshell/helios/
  shell.qml                  entry point — wires up one Bar (island) per screen + global overlays
  services/                  local singletons (Colors, Config, Bridge, Notifications, Weather, ExtraApps, Wallpaper) + Utils.js
  components/                shared widgets (MaterialIcon, StyledText, IconButton, Slider, Toggle,
                             LabeledNumberField, ...)
  modules/
    bar/                     the island itself — one PanelWindow per screen, anchored
                             top-center, content-sized instead of a fixed full-width pill:
      Bar.qml                 mode state machine (idle/peek/notify/media/volume/bluetooth/wifi/weather)
                               driving a spring-animated morph between shapes
      IslandShape.qml          fully-rounded pill body (all four corners — see margins.top in Bar.qml)
      LiquidGlassSurface.qml   optional translucent surface backed by real Hyprland blur
      IdleBump.qml             idle state: 12-hour clock + weather + a music-note glyph when media is active
      PeekContent.qml          hover state: workspaces, active window, clock, weather, tray, status
      NotifyCard.qml           auto-shown notification card (helios owns the DBus notification
                               server directly — no separate popup window); one notification gets
                               the full card, two or more collapse into a grouped list
      MediaCard.qml            MPRIS now-playing card (art, title/artist, seek, prev/play/next)
      PanelWrapper.qml         volume/Bluetooth/Wifi/media/weather tab switcher + close, wraps:
      VolumeTab.qml / BluetoothTab.qml / WifiTab.qml   the actual controls
      WeatherWidget.qml        current conditions from wttr.in; click opens WeatherSettings
      WeatherSettings.qml      set/clear a location override (city name or "lat,long")
      WallpaperSettings.qml    set/clear the wallpaper path
      IslandSettings.qml       tune idle-bump width/height/top-gap/font-size — persisted
                               in Config.qml itself, applies live
      Workspaces.qml, ActiveWindow.qml, Clock.qml, Tray.qml, StatusIndicators.qml   peek content
    launcher/                app search (drun-style): DesktopEntries (native + Flatpak, via
                             XDG_DATA_DIRS) merged with ExtraApps' own scan of Snap's desktop
                             directory, deduped by name
    osd/                     volume + brightness slider popup
    powermenu/                lock/logout/suspend/reboot/shutdown, with confirm-to-arm on destructive actions
    lock/                    session lock via wlr-session-lock + PAM (system-auth)
    wallpaper/               one background-layer image per screen (WlrLayer.Background,
                             below every real window), fill-cropped; path set from the
                             island's wallpaper panel or IPC
```

Colors, fonts, and sizing live in `services/Colors.qml` and `services/Config.qml` —
edit those first for a different look before touching module code.

The island reserves a small constant strip at the top of the screen regardless of
mode — `Config.islandTopGap` (just the pill's own margin from the true edge, so its
corner rounding is visible) and `Config.islandExclusiveZone` (the actual Hyprland
reservation: exactly top gap + idle-bump height, no more) — so Hyprland doesn't
reflow windows every time it hovers open; expanded states simply overlap whatever's
underneath rather than growing the reservation. `islandExclusiveZone` is deliberately
*not* padded any further than that: Hyprland's own `general:gaps_out` (and similar)
already adds its own space on top of this reservation when it places a window, so
extra padding here only stacked with that and made the gap under the bump visibly
bigger than the gap above it (which is a plain `margins.top`, untouched by Hyprland's
window-gap logic — there's no equivalent compositor-side padding added above the
island the way there is below it). If your `gaps_out` is unusually large, the two
gaps still won't match exactly — that remainder is coming from your Hyprland config,
not from helios. Idle-bump width/height, the top gap, and the base font size are all
user-tunable from the island's "Island" settings tab (or `ipc call island
appearance ...`) rather than hardcoded — see `setIslandAppearance` in
`services/Config.qml`. Liquid Glass needs `shell.qml`'s startup `hyprctl layerrule`
to have taken effect (it targets the `helios:bar` layer-shell namespace); if your
Hyprland version doesn't like the `--batch keyword layerrule` syntax used there,
toggling it will just look flat.

Weather's location override, the wallpaper path, the island's own appearance
settings, and the island's hit-test/paint-layer split all rely on Quickshell APIs
worth knowing about if you're extending this: `FileView` + `JsonAdapter` (see
`services/Weather.qml`, `services/Wallpaper.qml`, `services/Config.qml`) persist
settings to `Quickshell.statePath(...)` — under
`~/.local/state/quickshell/by-shell/<id>/` — without hand-rolled file I/O;
`PanelWindow.mask: Region { item: ... }` (see `Bar.qml`) restricts a layer-shell
surface's input to a sub-item's bounds so the rest of an oversized window stays
click-through; and `PanelWindow.exclusiveZone: -1` (see
`modules/wallpaper/Wallpaper.qml`) tells the compositor to ignore *other* surfaces'
exclusive-zone reservations — without it, the wallpaper's own fill got carved out by
the island's reserved top strip, showing as a plain black bar instead of image. The
same fix applies to any other full-screen (`anchors { top; bottom; left; right }`)
`PanelWindow` — Launcher, PowerMenu, and Keybinds all set it too, otherwise their dim
backdrop is carved out of that same reserved strip and the island shows through
undimmed at the top instead of being covered like the rest of the screen.

## Known limitations / next steps

- System tray icons only support left-click (activate) / right-click (secondary
  activate) — no DBusMenu context menu popup yet.
- Notifications only show as an island card (single or grouped) while pending — once
  cleared there's no persistent history to look back at.
- Only one notification server can own the `org.freedesktop.Notifications` DBus name at
  a time — if another daemon (Noctalia, mako, dunst, swaync, ...) is running, helios's
  notify card won't receive anything until that one is stopped.
- Hovering to peek and the volume/Bluetooth/Wifi/media/weather panels don't close on
  an outside click — use the panel's own close button, Escape, or re-trigger the same
  action (status icon click or IPC toggle).
- Weather defaults to whatever `wttr.in` resolves from this machine's public IP,
  refreshed every 20 minutes; set a location override in the island's weather panel
  (or `ipc call weather location "..."`) to pin it instead. Either way the widget just
  stays hidden if the lookup fails (offline, DNS, rate-limited, bad location string).
- Snap support in the launcher is written defensively against
  `/var/lib/snapd/desktop/applications` but untested — this machine doesn't have
  snapd installed. Flatpak apps are confirmed working (they come through
  Quickshell's own `DesktopEntries`, same as native packages).
- One wallpaper path for every screen — no per-monitor wallpapers, no crossfade
  between changes (it just swaps), and no built-in file picker (type or paste a path
  in the island's wallpaper panel).
