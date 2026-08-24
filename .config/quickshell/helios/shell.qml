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
import "./modules/wallpaper"

ShellRoot {
    // Themes is otherwise only referenced from IpcHandler function bodies and
    // from the (Loader-deferred) theme settings panel, so without this touch
    // the singleton never gets instantiated at startup — its
    // Component.onCompleted (which restores the saved palette into Colors)
    // would simply never run, leaving Colors on its hardcoded defaults until
    // the settings panel is opened once.
    QtObject {
        Component.onCompleted: Themes.currentLabel()
    }

    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Launcher {}
    Osd {}
    PowerMenu {}
    Keybinds {}
    Lock {}

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

    // Creates MediaCard's 8 named EasyEffects presets (Flat/Bass/Pop/...) the
    // first time helios runs anywhere — never overwrites ones that already
    // exist, so a user's own edits to them stick.
    Process {
        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/helios/modules/bar/easyeffects-eq.py", "--ensure-presets"]
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
}
