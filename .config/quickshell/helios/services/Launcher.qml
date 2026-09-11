pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string query: ""
    property var results: []
    property var windows: []
    property var launchCounts: ({})
    property string activationError: ""
    readonly property bool emojiMode: /^\/em(?:oji)?(?:\s+.*)?$/i.test(root.query.trim())

    readonly property var actions: [
        root._action("dnd", "Toggle Do Not Disturb", "notifications", "dnd silence", () => { Bridge.toggleDnd(); return true; }),
        root._action("nightlight", "Toggle Night Light", "eco", "color temperature blue light", () => { NightLight.toggle(); return true; }),
        root._action("idle", "Toggle Caffeine (keep awake)", "bolt", "idle inhibit sleep", () => { IdleInhibit.toggleInhibit(); return true; }),
        root._action("lock", "Lock Screen", "lock", "session", () => { Bridge.lock(); return true; }),
        root._destinationAction("powermenu", "Power Menu", "power_settings_new", "shutdown restart logout suspend"),
        root._destinationAction("keybinds", "Keybind Cheatsheet", "keyboard", "shortcuts binds"),
        root._action("screenshot-full", "Screenshot — Fullscreen", "crop", "capture screen", () => Screenshot.captureFullscreen()),
        root._action("screenshot-region", "Screenshot — Region", "crop", "capture screen slurp", () => Screenshot.captureRegion()),
        root._action("screenshot-window", "Screenshot — Active Window", "crop", "capture screen", () => Screenshot.captureWindow()),
        root._action("record", "Toggle Screen Recording", "movie", "record video gpu-screen-recorder", () => ScreenRecorder.toggle(IslandNavigation.screen))
    ].concat(IslandNavigation.destinations.filter(destination => !["launcher", "powermenu", "keybinds"].includes(destination.id)).map(destination =>
        root._destinationAction(destination.id, "Open " + destination.label, "", destination.label.toLowerCase() + " settings")))
      .concat(FocusModes.presets.map(preset => root._action("focus:" + preset.id,
        (FocusModes.activeId === preset.id ? "Turn Off " : "Turn On ") + preset.name,
        preset.icon || "center_focus_strong", "focus mode dnd caffeine", () => { FocusModes.toggle(preset); return true; })))

    readonly property var applications: {
        const seen = new Set();
        return DesktopEntries.applications.values.filter(entry => !entry.noDisplay)
            .concat(ExtraApps.list).filter(entry => {
                if (seen.has(entry.name)) return false;
                seen.add(entry.name);
                return true;
            });
    }

    function _action(id, title, icon, keywords, execute) {
        return { id: id, title: title, icon: icon, keywords: keywords, activation: { kind: "action", execute: execute } };
    }
    function _destinationAction(id, title, icon, keywords) {
        return root._action("destination:" + id, title, icon, keywords, () => IslandNavigation.select(id));
    }
    function _score(entry, needle) {
        const title = String(entry.title || "").toLowerCase();
        if (title === needle) return 4;
        if (title.startsWith(needle)) return 3;
        if (title.includes(needle)) return 2;
        if (String(entry.subtitle || "").toLowerCase().includes(needle)) return 1;
        if (String(entry.keywords || "").toLowerCase().includes(needle)) return 1;
        return 0;
    }
    function _count(name) { return root.launchCounts[name] || 0; }
    function _normalized(kind, source, score) {
        const title = kind === "window" ? source.title : kind === "action" ? source.title : source.name;
        return {
            id: kind + ":" + (kind === "window" ? source.address : kind === "action" ? source.id : title),
            kind: kind,
            title: title,
            subtitle: kind === "window" ? source.appClass : kind === "app" ? (source.genericName || "") : "",
            icon: source.icon || "",
            score: score || 0,
            entry: source,
            activation: kind === "window" ? { kind: "window", address: source.address }
                : kind === "app" ? { kind: "app", name: source.name } : source.activation
        };
    }

    function search(text) {
        root.query = text || "";
        const raw = root.query.trim();
        const emoji = raw.match(/^\/em(?:oji)?(?:\s+(.*))?$/i);
        if (emoji) {
            root.results = Emoji.search(emoji[1] || "", 9).map(item => ({
                id: "emoji:" + item.emoji, kind: "emoji", title: item.name || item.emoji,
                subtitle: item.keywords || "", icon: "", score: 0, entry: item,
                activation: { kind: "emoji", value: item.emoji }
            }));
            return root.results;
        }
        const needle = raw.toLowerCase();
        if (!needle) {
            root.results = root.applications.slice().sort((a, b) => root._count(b.name) - root._count(a.name) || a.name.localeCompare(b.name))
                .slice(0, 9).map(entry => root._normalized("app", entry, 0));
            return root.results;
        }
        const candidates = root.applications.map(entry => root._normalized("app", entry, root._score({ title: entry.name, subtitle: entry.genericName, keywords: entry.keywords }, needle)))
            .concat(root.windows.map(window => root._normalized("window", window, root._score({ title: window.title, subtitle: window.appClass }, needle))))
            .concat(root.actions.map(action => root._normalized("action", action, root._score(action, needle))))
            .filter(result => result.score > 0);
        root.results = candidates.sort((a, b) => b.score - a.score
            || (b.kind === "app" ? root._count(b.title) : 0) - (a.kind === "app" ? root._count(a.title) : 0)
            || (a.kind === "app" ? 0 : 1) - (b.kind === "app" ? 0 : 1)).slice(0, 9);
        return root.results;
    }

    function refreshWindows() { windowsProcess.running = false; windowsProcess.running = true; }
    function activate(result) {
        if (!result || !result.activation) return { accepted: false, close: false };
        root.activationError = "";
        const activation = result.activation;
        let accepted = true;
        if (activation.kind === "window") {
            focusProcess.command = ["hyprctl", "dispatch", "focuswindow", "address:" + activation.address];
            focusProcess.running = false; focusProcess.running = true;
        } else if (activation.kind === "app") {
            root.launchCounts = Object.assign({}, root.launchCounts, { [result.title]: root._count(result.title) + 1 });
            usageFile.setText(JSON.stringify(root.launchCounts));
            AppLaunch.launch(result.entry);
        } else if (activation.kind === "emoji") {
            emojiCopy.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", activation.value];
            emojiCopy.running = false; emojiCopy.running = true;
        } else if (activation.kind === "action") accepted = activation.execute() !== false;
        else accepted = false;
        if (accepted) IslandNavigation.close();
        else root.activationError = "Action could not be completed";
        return { accepted: accepted, close: accepted };
    }
    function runDesktopAction(action, appName) {
        if (appName) {
            root.launchCounts = Object.assign({}, root.launchCounts, { [appName]: root._count(appName) + 1 });
            usageFile.setText(JSON.stringify(root.launchCounts));
        }
        const command = action.command || [];
        if (command.length) Quickshell.execDetached(command);
        else {
            const parsed = String(action.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
            if (parsed) Quickshell.execDetached(["sh", "-c", parsed]);
            else return { accepted: false, close: false };
        }
        IslandNavigation.close();
        return { accepted: true, close: true };
    }

    property Process windowsProcess: Process {
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { onStreamFinished: {
            try { root.windows = JSON.parse(text).filter(window => window.mapped !== false && window.title)
                .map(window => ({ address: window.address, title: window.title, appClass: window["class"] || window.initialClass || "" })); }
            catch (error) { root.windows = []; }
            root.search(root.query);
        }}
    }
    property Process focusProcess: Process {}
    property Process emojiCopy: Process {}
    property FileView usageFile: FileView {
        path: Quickshell.statePath("launcher-app-usage.json"); printErrors: false; atomicWrites: true; preload: true; blockLoading: true
        onLoaded: { try { const parsed = JSON.parse(usageFile.text()); if (parsed && typeof parsed === "object") root.launchCounts = parsed; } catch (error) {} }
    }
    property Connections appChanges: Connections { target: DesktopEntries; function onApplicationsChanged() { root.search(root.query); } }
    property Connections extraChanges: Connections { target: ExtraApps; function onListChanged() { root.search(root.query); } }
    property Connections emojiChanges: Connections { target: Emoji; function onListChanged() { if (root.emojiMode) root.search(root.query); } }
}
