# Helios Shell

A [Quickshell](https://quickshell.org)-based desktop shell for [Hyprland](https://hyprland.org). Dynamic Island-style bar that morphs between idle, peek, notification, and full panel modes. Built for Fedora.

## Features

- **Dynamic Island bar** — idle pill → hover peek → full panel, spring-animated morphing
- **Notification server** — owns the DBus notification name, shows cards inline
- **Do Not Disturb** — suppresses popups, logs to history
- **Notification history** — browse dismissed notifications
- **Screenshot tool** — fullscreen, region (slurp), active window; copies to clipboard
- **Night Light** — wlsunset-based color temperature control with schedule
- **Display settings** — resolution, scale, VRR per monitor via hyprctl
- **Idle & Lock** — hypridle integration with dim/lock/DPMS timeouts + caffeine mode
- **Audio** — output/input device picker, volume control, mute
- **Bluetooth** — device discovery, connect/disconnect
- **WiFi** — network scan, connect with password, forget
- **Media** — MPRIS player with EQ presets (EasyEffects)
- **Clipboard history** — cliphist integration
- **Screen recording** — gpu-screen-recorder with fullscreen/window/region modes
- **Weather** — wttr.in with hourly forecast and 3-day daily
- **Activity tracking** — per-app focus time, weekly stats, heatmap
- **Wallpaper** — per-screen with 7 animated reveal transitions
- **Themes** — 10+ presets + dynamic from wallpaper (matugen); syncs GTK, Qt, Ghostty, btop, Neovim, Zed, Bat
- **Power profiles** — saver/balanced/performance via power-profiles-daemon
- **Launcher** — app search (XDG + Flatpak + Snap)
- **OSD** — volume + brightness overlays
- **Power menu** — lock/logout/suspend/reboot/shutdown
- **Lock screen** — PAM auth via wlr-session-lock
- **Keybind cheatsheet** — live from hyprctl binds
- **Liquid Glass** — optional compositor-blurred translucent surface

## Dependencies

```sh
# Core
sudo dnf copr enable lionheartp/hyprland
sudo dnf install quickshell hyprland

# Required
sudo dnf install brightnessctl wl-clipboard grim slurp jq

# Audio visualizer (optional — media art still shows without it)
sudo dnf install cava

# Clipboard history
sudo dnf copr enable wef/cliphist
sudo dnf install cliphist

# Dynamic theming
sudo dnf copr enable heus-sueh/packages
sudo dnf install matugen

# Night light
sudo dnf install wlsunset

# Idle management
sudo dnf install hypridle

# Screen recording
sudo dnf install gpu-screen-recorder

# Syntax highlighting theme sync (optional)
sudo dnf install bat

# Fonts
sudo dnf install inter-fonts jetbrains-mono-fonts
```

**Material Symbols icon font** (not packaged):

```sh
mkdir -p ~/.local/share/fonts
curl -sL -o ~/.local/share/fonts/MaterialSymbolsRounded.ttf \
  "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"
fc-cache -f ~/.local/share/fonts
```

## Install

```sh
git clone <this-repo> ~/Projects/helios-shell
cd ~/Projects/helios-shell
./link.sh
```

To uninstall: `./unlink.sh`

Files listed in `.linkignore` (regex patterns) are excluded from linking.

## Running

```sh
quickshell -c helios          # foreground
quickshell -c helios -d       # detached
```

Add to Hyprland autostart:

```
exec-once = quickshell -c helios
```

## Keybinds

Load `helios-binds.lua` from your Hyprland Lua config:

```lua
utils.safe_load("helios-binds")
```

| Bind | Action |
|------|--------|
| `Super+Space` | Launcher |
| `Super+L` | Lock |
| `Super+Escape` | Power menu |
| `Super+K` | Keybind cheatsheet |
| `Super+Shift+S` | Screenshot region |
| `Super+Print` | Screenshot fullscreen |
| `Super+Alt+S` | Screenshot window |
| `Super+Shift+N` | Toggle night light |
| `Super+Shift+D` | Toggle DND |
| `Super+Shift+F` | Toggle caffeine |
| `Super+Shift+C` | Start/stop recording |
| `Super+R` | Screen recorder panel |
| `Super+V` | Clipboard |
| `Super+Alt+Up/Down` | Brightness (with OSD) |
| `Super+Alt+V` | Clipboard island |
| `Super+Alt+B` | Idle/lock settings |
| `Super+Alt+D` | Display settings |
| `Super+Alt+H` | Notification history |
| `Super+Alt+L` | Night light |
| `Super+Alt+M` | Media player |
| `Super+Alt+N` | WiFi |
| `Super+Alt+W` | Weather |
| `Super+Alt+A` | Activity |
| `Super+Alt+P` | Wallpaper |
| `Super+Alt+T` | Theme |
| `Super+Alt+I` | Island settings |
| `Super+Alt+Escape` | Close island |
| `Super+Shift+T` | Apply dynamic theme |
| `Super+Shift+R` | Reload helios |

## IPC

All features are accessible via IPC:

```sh
quickshell -c helios ipc call <target> <function> [args...]
```

Targets: `launcher`, `lock`, `island`, `osd`, `weather`, `wallpaper`, `theme`, `clipboard`, `recorder`, `screenshot`, `dnd`, `nightlight`, `idle`, `keybinds`

## Layout

```
.config/quickshell/helios/
├── shell.qml              entry point
├── services/              singletons (Colors, Config, Bridge, Notifications,
│                          Weather, Activity, Themes, Cava, Clipboard,
│                          WifiNetworks, ScreenRecorder, MicActivity,
│                          Screenshot, NightLight, DisplaySettings, IdleInhibit)
├── components/            shared UI (IconButton, Slider, Toggle, StyledText, etc.)
└── modules/
    ├── bar/               Dynamic Island (per-screen)
    ├── launcher/          App search
    ├── osd/               Volume + brightness
    ├── powermenu/         Power actions
    ├── keybinds/          Live cheatsheet
    ├── lock/              Session lock (PAM)
    └── wallpaper/         Per-screen wallpaper + transitions
```

## License

MIT
