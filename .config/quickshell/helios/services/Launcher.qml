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
    // "list" = ranked results; "grid" = every application, alphabetical.
    property string view: "list"
    readonly property bool emojiMode: /^\/em(?:oji)?(?:\s+.*)?$/i.test(root.query.trim())
    readonly property bool clipboardMode: /^\/cb(?:\s+.*)?$/i.test(root.query.trim())
    onClipboardModeChanged: if (root.clipboardMode) Clipboard.refresh()

    readonly property var actions: root._allActions.filter(action => !action.id.startsWith("destination:")
        || !Config.destinationHidden(action.id.slice("destination:".length)))

    readonly property var _allActions: [
        root._action("dnd", "Toggle Do Not Disturb", "notifications", "dnd silence", () => { ShellState.toggleDnd(); return true; }),
        root._action("nightlight", "Toggle Night Light", "eco", "color temperature blue light", () => { NightLight.toggle(); return true; }),
        root._action("idle", "Toggle Caffeine (keep awake)", "bolt", "idle inhibit sleep", () => { IdleInhibit.toggleInhibit(); return true; }),
        root._action("lock", "Lock Screen", "lock", "session", () => { ShellState.lock(); return true; }),
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

    function _action(id, title, icon, keywords, execute, keepOpen) {
        return { id: id, title: title, icon: icon, keywords: keywords, activation: { kind: "action", execute: execute, keepOpen: !!keepOpen } };
    }
    // Swaps the open Island to another destination, so the Island must stay
    // open afterwards instead of closing like other actions.
    function _destinationAction(id, title, icon, keywords) {
        return root._action("destination:" + id, title, icon, keywords, () => IslandNavigation.select(id), true);
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

    // Arithmetic in the query ("12*4", "(3+4)^2") becomes a result that
    // copies the answer. The character whitelist keeps evaluation to math.
    function _calculate(raw) {
        const expression = raw.replace(/,/g, "");
        if (!/^[\d\s+\-*\/%^().]+$/.test(expression) || !/\d\s*[-+*\/%^]\s*[\d(.]/.test(expression)) return null;
        try {
            const value = Function("return (" + expression.replace(/\^/g, "**") + ");")();
            if (typeof value !== "number" || !isFinite(value)) return null;
            const answer = String(Number(value.toPrecision(12)));
            return { id: "calc:" + answer, kind: "calc", title: answer, subtitle: raw + " — copy result", icon: "calculate",
                score: 0, entry: { icon: "calculate" }, activation: { kind: "copy", value: answer } };
        } catch (error) {
            return null;
        }
    }

    // "10 km to mi", "72 f in c", "2 gib to mb" becomes a result that copies
    // the converted value. Units in one group convert through a shared base.
    readonly property var _unitGroups: [
        { m: 1, km: 1000, cm: 0.01, mm: 0.001, mi: 1609.344, yd: 0.9144, ft: 0.3048, in: 0.0254 },
        { kg: 1, g: 0.001, mg: 1e-6, lb: 0.45359237, oz: 0.028349523125 },
        { l: 1, ml: 0.001, gal: 3.785411784 },
        { s: 1, min: 60, h: 3600, day: 86400 },
        { b: 1, kb: 1e3, mb: 1e6, gb: 1e9, tb: 1e12, kib: 1024, mib: 1048576, gib: 1073741824 },
        { c: "c", f: "f", k: "k" }
    ]
    function _convert(raw) {
        const match = raw.replace(/,/g, "").match(/^(-?\d*\.?\d+)\s*([a-z]+)\s+(?:to|in|as)\s+([a-z]+)$/i);
        if (!match) return null;
        const amount = Number(match[1]), from = match[2].toLowerCase(), to = match[3].toLowerCase();
        const group = root._unitGroups.find(units => from in units && to in units);
        if (!group || from === to) return null;
        let value;
        if (typeof group[from] === "string") {
            const celsius = from === "c" ? amount : from === "f" ? (amount - 32) * 5 / 9 : amount - 273.15;
            value = to === "c" ? celsius : to === "f" ? celsius * 9 / 5 + 32 : celsius + 273.15;
        } else {
            value = amount * group[from] / group[to];
        }
        const answer = String(Number(value.toPrecision(8)));
        return { id: "convert:" + answer + to, kind: "calc", title: answer + " " + match[3], subtitle: raw + " — copy result",
            icon: "straighten", score: 0, entry: { icon: "straighten" }, activation: { kind: "copy", value: answer } };
    }
    function _webSearch(raw) {
        return root._normalized("action", root._action("web-search", "Search the web for \u201c" + raw + "\u201d", "travel_explore", "",
            () => { Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(raw)]); return true; }), 0);
    }
    function _clipboardResults(needle) {
        return Clipboard.items.filter(item => !item.isImage && (!needle || item.preview.toLowerCase().includes(needle))).slice(0, 9)
            .map(item => ({ id: "clip:" + item.id, kind: "clip", title: item.preview.trim(), subtitle: "Clipboard", icon: "content_paste",
                score: 0, entry: { icon: "content_paste" }, activation: { kind: "action", execute: () => { Clipboard.copy(item.line); return true; } } }));
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
        const clip = raw.match(/^\/cb(?:\s+(.*))?$/i);
        if (clip) {
            root.results = root._clipboardResults((clip[1] || "").toLowerCase());
            return root.results;
        }
        const needle = raw.toLowerCase();
        if (root.view === "grid") {
            root.results = root.applications
                .filter(entry => !needle || root._score({ title: entry.name, subtitle: entry.genericName, keywords: entry.keywords }, needle) > 0)
                .sort((a, b) => a.name.localeCompare(b.name))
                .map(entry => root._normalized("app", entry, 0));
            return root.results;
        }
        if (!needle) {
            root.results = root.applications.slice().sort((a, b) => root._count(b.name) - root._count(a.name) || a.name.localeCompare(b.name))
                .slice(0, 9).map(entry => root._normalized("app", entry, 0));
            return root.results;
        }
        const candidates = root.applications.map(entry => root._normalized("app", entry, root._score({ title: entry.name, subtitle: entry.genericName, keywords: entry.keywords }, needle)))
            .concat(root.windows.map(window => root._normalized("window", window, root._score({ title: window.title, subtitle: window.appClass }, needle))))
            .concat(root.actions.map(action => root._normalized("action", action, root._score(action, needle))))
            .filter(result => result.score > 0);
        const answer = root._calculate(raw) || root._convert(raw);
        // The web search always stays last, inside the 9-row limit.
        root.results = (answer ? [answer] : []).concat(candidates.sort((a, b) => b.score - a.score
            || (b.kind === "app" ? root._count(b.title) : 0) - (a.kind === "app" ? root._count(a.title) : 0)
            || (a.kind === "app" ? 0 : 1) - (b.kind === "app" ? 0 : 1))).slice(0, 8).concat([root._webSearch(raw)]);
        return root.results;
    }

    function setView(view) {
        root.view = view;
        root.search(root.query);
    }
    // Opens the Launcher on screenName showing all applications.
    function showApps(screenName) {
        if (IslandNavigation.show(screenName, "launcher")) root.setView("grid");
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
            root.recordLaunch(result.title);
            AppLaunch.launch(result.entry);
        } else if (activation.kind === "emoji" || activation.kind === "copy") {
            copyProcess.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", activation.value];
            copyProcess.running = false; copyProcess.running = true;
        } else if (activation.kind === "action") accepted = activation.execute() !== false;
        else accepted = false;
        const close = accepted && !activation.keepOpen;
        if (close) IslandNavigation.close();
        if (!accepted) root.activationError = "Action could not be completed";
        return { accepted: accepted, close: close };
    }
    // Counts a launch toward the empty-query "most used" ranking. Called for
    // launches from anywhere (Launcher, Dock), keyed by app name.
    function recordLaunch(appName) {
        if (!appName) return;
        root.launchCounts = Object.assign({}, root.launchCounts, { [appName]: root._count(appName) + 1 });
        usageFile.setText(JSON.stringify(root.launchCounts));
    }
    function runDesktopAction(action, appName) {
        if (appName) root.recordLaunch(appName);
        const command = action.command || [];
        if (command.length) AppLaunch.exec(command);
        else {
            const parsed = String(action.execString || "").replace(/%[fFuUdDnNickvm]/g, "").trim();
            if (parsed) AppLaunch.exec(["sh", "-c", parsed]);
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
    property Process copyProcess: Process {}
    property FileView usageFile: FileView {
        path: Quickshell.statePath("launcher-app-usage.json"); printErrors: false; atomicWrites: true; preload: true; blockLoading: true
        onLoaded: { try { const parsed = JSON.parse(usageFile.text()); if (parsed && typeof parsed === "object") root.launchCounts = parsed; } catch (error) {} }
    }
    // Every other way into the Launcher starts from the ranked list.
    property Connections navigationChanges: Connections {
        target: IslandNavigation
        function onOpenChanged() { root._resetView(); }
        function onDestinationIdChanged() { root._resetView(); }
    }
    function _resetView() {
        if (!(IslandNavigation.open && IslandNavigation.destinationId === "launcher")) root.view = "list";
    }
    property Connections appChanges: Connections { target: DesktopEntries; function onApplicationsChanged() { root.search(root.query); } }
    property Connections extraChanges: Connections { target: ExtraApps; function onListChanged() { root.search(root.query); } }
    property Connections clipboardChanges: Connections { target: Clipboard; function onItemsChanged() { if (root.clipboardMode) root.search(root.query); } }
    property Connections emojiChanges: Connections { target: Emoji; function onListChanged() { if (root.emojiMode) root.search(root.query); } }
}
