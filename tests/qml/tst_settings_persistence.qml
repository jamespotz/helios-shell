import QtQuick
import Quickshell
import Quickshell.Io
import services

ShellRoot {
    id: root
    readonly property string scope: Quickshell.env("HELIOS_SETTINGS_TEST_SCOPE")
    readonly property bool writing: Quickshell.env("HELIOS_SETTINGS_TEST_PHASE") === "write"
    readonly property string folder: Quickshell.env("HOME") + "/wallpapers"
    property int defaultAppIndex: 0
    readonly property Process terminator: Process { command: ["sh", "-c", "kill -TERM $PPID"] }
    readonly property Timer terminateDelay: Timer { interval: 50; onTriggered: root.terminator.running = true }

    function compare(actual, expected, label) {
        if (JSON.stringify(actual) !== JSON.stringify(expected))
            throw new Error(label + ": expected " + JSON.stringify(expected) + ", got " + JSON.stringify(actual));
    }
    function finish(error) {
        if (error) console.error("SETTINGS_PERSISTENCE_TEST_FAIL", root.scope, error.toString());
        else console.warn("SETTINGS_PERSISTENCE_TEST_PASS", root.scope, root.writing ? "write" : "read");
        root.terminateDelay.start();
    }

    function sample(key, option) {
        if (option.choices) return option.choices.find(v => v !== option.value);
        if (option.range) return option.value === option.range[1] ? option.range[0] : option.range[1];
        if (typeof option.value === "boolean") return !option.value;
        if (Array.isArray(option.value)) {
            if (key === "idleLayout" || key === "peekLayout")
                return Config.widgetKeys[key === "idleLayout" ? "idle" : "peek"].slice().reverse().concat(["|"]);
            return ["weather"];
        }
        return "Persistence test";
    }

    function options(target) {
        for (const key of Object.keys(target.options)) {
            const expected = root.sample(key, target.options[key]);
            if (root.writing) target.setOption(key, expected);
            else {
                const actual = target === Config ? Config.settingsFile.adapter[key] : target[key];
                root.compare(actual, expected, root.scope + "." + key);
                if (target === Config && Config[key] !== undefined)
                    root.compare(Config[key], expected, "effective Config." + key);
            }
        }
    }

    Component.onCompleted: {
        // Instantiate the selected singleton before waiting for its async load.
        switch (root.scope) {
        case "config": Config.settingsFile; break;
        case "dock": Dock.settingsFile; break;
        case "shell": ShellState.liquidGlassFile; break;
        case "automatic-dnd": ShellState.liquidGlassFile; break;
        case "idle": IdleInhibit.settingsFile; break;
        case "nightlight": NightLight.settingsFile; break;
        case "weather": Weather.loading = true; Weather.settingsFile; break;
        case "theme": Themes.settingsFile; break;
        case "focus": FocusModes.presetsFile; break;
        case "automations": Automations.settingsFile; break;
        case "wallpaper": WallpaperLibrary.settingsFile; break;
        case "default-apps": DefaultApps.current; break;
        }
        root.runTests.start();
    }

    readonly property Timer runTests: Timer {
        interval: 200
        onTriggered: {
            try {
                switch (root.scope) {
                case "config":
                    root.options(Config);
                    if (root.writing) {
                        Config.setWorkspaceIcon("3", "star");
                        Config.setIslandShownOn("TEST-MONITOR", false);
                    } else {
                        root.compare(Config.workspaceIcons["3"], "star", "workspace icon");
                        root.compare(Config.islandShownOn("TEST-MONITOR"), false, "Island screen visibility");
                        root.compare(Config.idleWidgetLayout, root.sample("idleLayout", Config.options.idleLayout), "idle layout");
                        root.compare(Config.peekWidgetLayout, root.sample("peekLayout", Config.options.peekLayout), "peek layout");
                    }
                    break;
                case "dock":
                    root.options(Dock);
                    if (root.writing) {
                        Dock.pin("persistence-test.desktop");
                        Dock.setShownOn("TEST-MONITOR", false);
                    } else {
                        root.compare(Dock.pins.includes("persistence-test.desktop"), true, "Dock pins");
                        root.compare(Dock.hiddenScreens.includes("TEST-MONITOR"), true, "Dock screens");
                    }
                    break;
                case "shell":
                    if (root.writing) { ShellState.setDndEnabled(true); ShellState.liquidGlassEnabled = true; }
                    else {
                        root.compare(ShellState.dndEnabled, true, "Do Not Disturb");
                        root.compare(ShellState.liquidGlassEnabled, true, "liquid glass");
                    }
                    break;
                case "automatic-dnd":
                    if (root.writing) {
                        ShellState.setDndEnabled(false);
                        ShellState.automaticDndEnabled = true;
                        ShellState.liquidGlassEnabled = true;
                    } else {
                        root.compare(ShellState.dndEnabled, false, "temporary fullscreen DND must not persist");
                        root.compare(ShellState.liquidGlassEnabled, true, "manual preference still persists");
                    }
                    break;
                case "idle":
                    if (root.writing) {
                        IdleInhibit.setEnabled(false);
                        IdleInhibit.setLockTimeout(420);
                        IdleInhibit.setDpmsTimeout(840);
                        IdleInhibit.setDimTimeout(180);
                        IdleInhibit.toggleInhibit();
                    } else {
                        root.compare([IdleInhibit.enabled, IdleInhibit.lockTimeout, IdleInhibit.dpmsTimeout,
                            IdleInhibit.dimTimeout, IdleInhibit.inhibited], [false, 420, 840, 180, true], "idle settings");
                    }
                    break;
                case "nightlight":
                    if (root.writing) {
                        NightLight.setTemperature(3500);
                        NightLight.setScheduled(true);
                        NightLight.setEnabled(true);
                    } else root.compare([NightLight.enabled, NightLight.temperature, NightLight.scheduled], [true, 3500, true], "night light");
                    break;
                case "weather":
                    if (root.writing) Weather.setLocation("14.6,121.0");
                    else root.compare(Weather.locationOverride, "14.6,121.0", "weather location");
                    break;
                case "theme":
                    if (root.writing) {
                        Themes.applyPreset(Themes.presetOrder[1]);
                        Themes.setPaletteScheme("scheme-expressive");
                        Themes.setDynamicMode(false);
                    } else root.compare([Themes.mode, Themes.presetName, Themes.paletteScheme, Themes.dynamicDark],
                        ["preset", Themes.presetOrder[1], "scheme-expressive", false], "theme selection");
                    break;
                case "focus":
                    if (root.writing) {
                        FocusModes.updatePreset("focus", { name: "Saved Focus", apps: ["test.desktop"], caffeine: false });
                        FocusModes.activeId = "focus";
                    } else {
                        root.compare(FocusModes.presets[0].name, "Saved Focus", "Focus preset");
                        root.compare(FocusModes.presets[0].apps, ["test.desktop"], "Focus apps");
                        root.compare(FocusModes.presets[0].caffeine, false, "Focus caffeine");
                        root.compare(FocusModes.activeId, "focus", "active Focus selection");
                    }
                    break;
                case "automations":
                    for (const rule of ["Headphones", "BluetoothAudio", "Monitor", "Battery", "Ac", "Fullscreen"]) {
                        if (root.writing) Automations["set" + rule + "Rule"](true);
                        else root.compare(Automations[rule.charAt(0).toLowerCase() + rule.slice(1) + "Rule"], true, rule + " automation");
                    }
                    break;
                case "wallpaper":
                    if (root.writing) {
                        WallpaperLibrary.setFolder(root.folder);
                        WallpaperLibrary.setPath(root.folder + "/b.png");
                        WallpaperLibrary._storeImages([root.folder + "/b.png", root.folder + "/a.png"], true);
                    } else {
                        root.compare(WallpaperLibrary.folderPath, root.folder, "wallpaper folder");
                        root.compare(WallpaperLibrary.path, root.folder + "/b.png", "wallpaper selection");
                        root.compare(WallpaperLibrary._storedImages(), [root.folder + "/b.png", root.folder + "/a.png"], "wallpaper library order");
                    }
                    break;
                case "default-apps":
                    if (DefaultApps.browserQuery.running || DefaultApps.filemanagerQuery.running || DefaultApps.editorQuery.running) {
                        root.runTests.restart();
                        return;
                    }
                    if (root.writing) {
                        root.writeDefaultApps.start();
                        return;
                    }
                    for (const category of DefaultApps.categories)
                        root.compare(DefaultApps.current[category.id], "persistence-" + category.id + ".desktop", category.id + " default app");
                    break;
                default: throw new Error("unknown test scope");
                }
                if (root.writing) root.saved.start();
                else root.finish();
            } catch (error) { root.finish(error); }
        }
    }
    readonly property Timer saved: Timer { interval: 700; onTriggered: root.finish() }
    readonly property Timer writeDefaultApps: Timer {
        interval: 150
        repeat: true
        onTriggered: {
            if (DefaultApps.setProc.running) return;
            if (root.defaultAppIndex === DefaultApps.categories.length) {
                stop();
                root.saved.start();
                return;
            }
            const category = DefaultApps.categories[root.defaultAppIndex++];
            DefaultApps.setDefault(category.id, "persistence-" + category.id + ".desktop");
        }
    }
}
