//@ pragma UseQApplication
// Default state dir is keyed by an MD5 hash of the resolved config path —
// launching via `-c helios` vs `-p <repo path>` (or any other path
// inconsistency, e.g. symlink resolution) hashes differently and orphans
// previously persisted state (wallpaper, island settings, etc.) under a
// different by-shell/<id>/ dir. Pin it so state always lands in the same
// place regardless of how the shell was launched.
//@ pragma StateDir $BASE/helios
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "./services"
import "./services/Utils.js" as Utils
import "./modules/bar"
import "./modules/osd"
import "./modules/lock"
import "./modules/polkit"

ShellRoot {
    id: shellRoot
    property bool startupWallpaperRestored: false

    function restoreStartupWallpaper() {
        if (shellRoot.startupWallpaperRestored || !WallpaperLibrary.settingsReady)
            return;
        shellRoot.startupWallpaperRestored = true;
        Wallpaper.restore();
    }

    Connections {
        target: WallpaperLibrary
        function onSettingsLoaded() { shellRoot.restoreStartupWallpaper() }
    }

    Connections {
        target: Calendar
        function onMeetingFocusRequested(presetId) {
            const preset = FocusModes.presets.find(candidate => candidate.id === presetId);
            if (preset) FocusModes.apply(preset);
        }
    }

    // Restore always-on state and start slow panel data loads while the shell
    // is idle. The island then reads the populated singleton caches.
    QtObject {
        Component.onCompleted: {
            Themes.currentLabel();
            NightLight.enabled;    // restores persisted state + spawns wlsunset if needed
            IdleInhibit.enabled;   // restores persisted state + spawns hypridle if needed
            WallpaperLibrary.images;
            shellRoot.restoreStartupWallpaper();
            WifiNetworks.networks;
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Osd {}
    Lock {}
    TrayMenu {}
    PolkitAgent {}
    SettingsWindow {}

    // Lets the (experimental) Liquid Glass surface read real desktop pixels
    // through Hyprland's compositor blur instead of faking translucency.
    // Matches every screen's Bar plus the settings window, which now shares
    // the same LiquidGlassSurface toggle.
    Process {
        running: true
        command: [
            "hyprctl", "--batch",
            "keyword layerrule blur,namespace:^(helios:bar|helios:settings)$ ; " +
            "keyword layerrule ignorealpha 0.15,namespace:^(helios:bar|helios:settings)$ ; " +
            "keyword layerrule xray 0,namespace:^(helios:bar|helios:settings)$"
        ]
    }

    IpcHandler {
        target: "launcher"
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "launcher");
        }
        function open() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.show(screen.name, "launcher");
        }
        function close() { IslandNavigation.close() }
    }

    IpcHandler {
        target: "island"
        function toggle(tab: string) {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, tab && tab.length > 0 ? tab : "volume");
        }
        function close() { IslandNavigation.close() }
        function liquidGlass(enabled: bool) { Bridge.liquidGlassEnabled = enabled }
        function appearance(width: int, height: int, gap: int, widgetSpacing: int) {
            Config.setIslandAppearance(width, height, gap, widgetSpacing);
        }
        function resetAppearance() { Config.resetIslandAppearance() }
        function font(family: string, size: int) { Config.setFont(family, size) }
    }

    IpcHandler {
        target: "weather"
        function location(text: string) { Weather.setLocation(text) }
    }


    IpcHandler {
        target: "wallpaper"
        function set(path: string) { Wallpaper.select(path) }
        function folder(path: string) { Wallpaper.setFolder(path) }
    }

    IpcHandler {
        target: "theme"
        function apply(name: string) { Themes.applyPreset(name) }
        function dynamic() { Themes.applyDynamic() }
    }

    IpcHandler {
        target: "keybinds"
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "keybinds");
        }
        function close() { IslandNavigation.close() }
    }

    IpcHandler {
        target: "powermenu"
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "powermenu");
        }
        function close() { IslandNavigation.close() }
    }

    IpcHandler {
        target: "lock"
        function lock() { Bridge.lock() }
    }

    IpcHandler {
        target: "settings"
        function toggle(page: string) {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            Bridge.toggleSettings(screen.name, page && page.length > 0 ? page : undefined);
        }
        function open(page: string) {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            Bridge.openSettings(screen.name, page && page.length > 0 ? page : undefined);
        }
        function close() { Bridge.closeSettings() }
    }

    IpcHandler {
        target: "clipboard"
        // Returns whatever's currently cached (populated whenever the
        // island's clipboard tab has been opened) — `cliphist list` itself
        // runs async, so a fresh spawn-and-wait isn't available synchronously
        // here. Call `refresh` first if you need it current before listing.
        function list(): string { return Clipboard.items.map(i => i.preview).join("\n") }
        function refresh() { Clipboard.refresh() }
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "clipboard");
        }
    }

    IpcHandler {
        target: "recorder"
        // Starts/stops against whichever monitor Hyprland currently has
        // focused — same "focused" convention as the `island` handler —
        // so a hotkey works regardless of which screen's island it opens.
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            ScreenRecorder.toggle(screen.name);
        }
        function stop() { ScreenRecorder.stop() }
        function mode(name: string) { ScreenRecorder.setMode(name) }
    }

    IpcHandler {
        target: "screenshot"
        function full() { Screenshot.captureFullscreen() }
        function region() { Screenshot.captureRegion() }
        function window() { Screenshot.captureWindow() }
        function ocr() { Screenshot.captureOcrRegion() }
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "screenshot");
        }
    }

    IpcHandler {
        target: "dnd"
        function toggle() { Bridge.toggleDnd() }
        function on() { Bridge.dndEnabled = true }
        function off() { Bridge.dndEnabled = false }
    }

    IpcHandler {
        target: "nightlight"
        function toggle() { NightLight.toggle() }
        function on() { NightLight.setEnabled(true) }
        function off() { NightLight.setEnabled(false) }
        function temp(value: int) { NightLight.setTemperature(value) }
        function schedule(enabled: bool) { NightLight.setScheduled(enabled) }
    }

    IpcHandler {
        target: "power"
        function balanced() { PowerProfiles.profile = PowerProfile.Balanced }
        function powersave() { PowerProfiles.profile = PowerProfile.PowerSaver }
        function performance() { if (PowerProfiles.hasPerformanceProfile) PowerProfiles.profile = PowerProfile.Performance }
        // Same order PowerIsland.qml renders its segments in. Skips Performance
        // when the system doesn't expose it (same guard PowerIsland uses).
        function cycle() {
            const order = PowerProfiles.hasPerformanceProfile
                ? [PowerProfile.Balanced, PowerProfile.PowerSaver, PowerProfile.Performance]
                : [PowerProfile.Balanced, PowerProfile.PowerSaver];
            const next = (order.indexOf(PowerProfiles.profile) + 1) % order.length;
            PowerProfiles.profile = order[next];
        }
    }

    IpcHandler {
        target: "audio"
        function outputs(): string {
            return Audio.sinks.map(n => n.name + "\t" + (n.description || n.nickname || n.name)).join("\n");
        }
        function inputs(): string {
            return Audio.sources.map(n => n.name + "\t" + (n.description || n.nickname || n.name)).join("\n");
        }
        function setOutput(match: string) { Audio.setOutput(match) }
        function setInput(match: string) { Audio.setInput(match) }
    }

    IpcHandler {
        target: "idle"
        function caffeine() { IdleInhibit.toggleInhibit() }
        function enable() { IdleInhibit.setEnabled(true) }
        function disable() { IdleInhibit.setEnabled(false) }
    }

    IpcHandler {
        target: "systemmonitor"
        // Own ipc (vs. `island toggle system`) so a hotkey keeps working
        // even if the system monitor tab's island target ever changes —
        // same convention as `clipboard toggle`/`recorder toggle` above.
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "system");
        }
    }

    IpcHandler {
        target: "automation"
        // Own ipc (vs. `island toggle automation`) so a hotkey keeps working
        // even if the automation tab's island target ever changes — same
        // convention as `clipboard toggle`/`recorder toggle` above.
        function toggle() {
            const screen = Utils.focusedScreen(Quickshell.screens, Hyprland.focusedMonitor);
            IslandNavigation.toggle(screen.name, "automation");
        }
    }

    IpcHandler {
        target: "focus"
        function apply(id: string) {
            const preset = FocusModes.presets.find(p => p.id === id);
            if (preset) FocusModes.apply(preset);
        }
        function off() { FocusModes.deactivate() }
    }

    // Lets any shell script or keybind report progress on a long-running
    // command (or a file transfer) so the Island can auto-peek it, the same
    // way a DBus notification auto-peeks — e.g.:
    //   quickshell -c helios ipc call task start build "Building project"
    //   quickshell -c helios ipc call task progress build 0.5
    //   quickshell -c helios ipc call task done build true
    IpcHandler {
        target: "task"
        function start(id: string, label: string) { Tasks.start(id, label) }
        function progress(id: string, value: real, label: string) { Tasks.progress(id, value, label) }
        function done(id: string, ok: bool) { Tasks.finish(id, ok) }
    }
}
