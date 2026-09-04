//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./services"
import "./services/Utils.js" as Utils
import "./modules/bar"
import "./modules/launcher"
import "./modules/osd"
import "./modules/powermenu"
import "./modules/keybinds"
import "./modules/lock"

ShellRoot {
    // Restore services whose state affects always-on shell behavior. Panel-only
    // services initialize when their panel first opens.
    QtObject {
        Component.onCompleted: {
            Themes.currentLabel();
            NightLight.enabled;    // restores persisted state + spawns wlsunset if needed
            IdleInhibit.enabled;   // restores persisted state + spawns hypridle if needed
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    LazyLoader {
        activeAsync: Bridge.launcherOpen
        Launcher {}
    }
    Osd {}
    PowerMenu {}
    Keybinds {}
    Lock {}
    TrayMenu {}

    // Lets the (experimental) Liquid Glass surface read real desktop pixels
    // through Hyprland's compositor blur instead of faking translucency.
    // Matches every screen's Bar since they all share the "helios:bar"
    // layer-shell namespace.
    Process {
        running: true
        command: [
            "hyprctl", "--batch",
            "keyword layerrule blur,namespace:^(helios:bar)$ ; " +
            "keyword layerrule ignorealpha 0.15,namespace:^(helios:bar)$ ; " +
            "keyword layerrule xray 0,namespace:^(helios:bar)$"
        ]
    }

    IpcHandler {
        target: "launcher"
        function toggle() { Bridge.toggleLauncher() }
        function open() { Bridge.launcherOpen = true }
        function close() { Bridge.launcherOpen = false }
    }

    IpcHandler {
        target: "island"
        function toggle(tab: string) {
            const screen = Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0];
            Bridge.toggleIsland(screen.name, tab && tab.length > 0 ? tab : "volume");
        }
        function close() { Bridge.closeIsland() }
        function liquidGlass(enabled: bool) { Bridge.liquidGlassEnabled = enabled }
        function appearance(width: int, height: int, gap: int, fontSize: int) {
            Config.setIslandAppearance(width, height, gap, fontSize);
        }
        function resetAppearance() { Config.resetIslandAppearance() }
    }

    IpcHandler {
        target: "weather"
        function location(text: string) { Weather.setLocation(text) }
    }


    IpcHandler {
        target: "wallpaper"
        function set(path: string) { Wallpaper.setPath(path) }
        function folder(path: string) { Wallpaper.setFolder(path) }
    }

    IpcHandler {
        target: "theme"
        function apply(name: string) { Themes.applyPreset(name) }
        function dynamic() { Themes.applyDynamic() }
    }

    IpcHandler {
        target: "keybinds"
        function toggle() { Bridge.toggleKeybinds() }
        function close() { Bridge.closeKeybinds() }
    }

    IpcHandler {
        target: "lock"
        function lock() { Bridge.lock() }
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
            const screen = Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0];
            Bridge.toggleIsland(screen.name, "clipboard");
        }
    }

    IpcHandler {
        target: "recorder"
        // Starts/stops against whichever monitor Hyprland currently has
        // focused — same "focused" convention as the `island` handler —
        // so a hotkey works regardless of which screen's island it opens.
        function toggle() {
            const screen = Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0];
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
            const screen = Utils.screenForMonitor(Quickshell.screens, Hyprland.focusedMonitor) || Quickshell.screens[0];
            Bridge.toggleIsland(screen.name, "system");
        }
    }
}
